// Isolated PostgreSQL tests for 20261020100000_ensure_vendor_shop.sql; never
// connects to the live project.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const artisan = '10000000-0000-0000-0000-000000000001', buyer = '10000000-0000-0000-0000-000000000002',
  nameless = '10000000-0000-0000-0000-000000000003', withShop = '10000000-0000-0000-0000-000000000004';
let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); passed++; };
async function failure(sql) { try { await db.exec(sql); } catch (e) { return e; } return null; }
const rows = async sql => (await db.query(sql)).rows;
const migration = name => readFileSync(new URL(`../supabase/migrations/${name}`, import.meta.url), 'utf8');
async function as(id) { await db.exec(`reset role;set role ${id ? 'authenticated' : 'anon'};select set_config('test.uid','${id ?? ''}',false);`); }

try {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  grant usage on schema auth,public to anon,authenticated,service_role;
  create table profiles(id uuid primary key,role text not null default 'buyer',display_name text);
  create table shops(id uuid primary key default gen_random_uuid(),vendor_id uuid unique,name text not null,slug text not null unique,
    bio text,location text,is_active boolean default true);
  create table vendor_applications(id uuid primary key default gen_random_uuid(),user_id uuid,applicant_user_id_snapshot uuid,
    business_name text,location text,status text,created_at timestamptz default now());
  alter table shops enable row level security; alter table profiles enable row level security;
  create policy shops_read on shops for select using(true);
  grant select on shops to anon,authenticated,service_role;
  insert into profiles values('${artisan}','vendor','Nicky'),('${buyer}','buyer','Buyer'),('${nameless}','vendor',null),('${withShop}','vendor','Has Shop');
  insert into vendor_applications(user_id,applicant_user_id_snapshot,business_name,location,status,created_at)
    values('${artisan}','${artisan}','Old Name','Paarl','rejected',now()-interval '2 days'),
          ('${artisan}','${artisan}','Tide & Towel','Cape Town','approved',now()-interval '1 day');
  insert into shops(vendor_id,name,slug) values('${withShop}','Existing','existing-1');`);
  await db.exec(migration('20261020100000_ensure_vendor_shop.sql'));

  await as(artisan);
  const first = (await rows(`select public.ensure_vendor_shop() as id`))[0].id;
  const shop = (await rows(`select * from shops where vendor_id='${artisan}'`))[0];
  ok('an approved artisan without a shop gets one', shop && shop.id === first);
  ok('it is named from the approved application', shop.name === 'Tide & Towel' && shop.location === 'Cape Town');
  ok('it is active with a readable slug', shop.is_active === true && /^tide-towel-\d{6}$/.test(shop.slug));
  ok('calling again returns the same shop', (await rows(`select public.ensure_vendor_shop() as id`))[0].id === first);
  ok('no duplicate shop is created', (await rows(`select count(*)::int n from shops where vendor_id='${artisan}'`))[0].n === 1);

  await as(withShop);
  ok('an artisan who already has a shop keeps it', (await rows(`select public.ensure_vendor_shop() as id`))[0].id
    === (await rows(`select id from shops where vendor_id='${withShop}'`))[0].id);

  await as(nameless);
  await db.exec(`select public.ensure_vendor_shop()`);
  ok('without an application or name the shop is still created', (await rows(`select name from shops where vendor_id='${nameless}'`))[0].name === 'My shop');

  await as(buyer);
  ok('a buyer cannot create a shop', !!(await failure(`select public.ensure_vendor_shop()`)));
  ok('a member cannot create a shop for someone else', !!(await failure(`select public.create_vendor_shop_from_application('${buyer}')`)));
  await as(null);
  ok('a guest cannot call it', !!(await failure(`select public.ensure_vendor_shop()`)));

  console.log(`${passed} ensure-vendor-shop assertions passed`);
} catch (error) { console.error(error.message); process.exitCode = 1; } finally { await db.close(); }
