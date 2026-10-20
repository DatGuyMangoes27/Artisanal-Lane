// Isolated PostgreSQL tests for 20261020120000_multi_shop_checkout_groups.sql;
// never connects to the live project.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const buyer = '20000000-0000-0000-0000-000000000001', other = '20000000-0000-0000-0000-000000000002';
const shop = '30000000-0000-0000-0000-000000000001', product = '40000000-0000-0000-0000-000000000001';
const variant = '50000000-0000-0000-0000-000000000001';
const pendingA = '60000000-0000-0000-0000-000000000001', pendingB = '60000000-0000-0000-0000-000000000002';
const paid = '60000000-0000-0000-0000-000000000003';
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
  create table profiles(id uuid primary key);
  create table products(id uuid primary key,stock_qty int not null,updated_at timestamptz);
  create table product_variants(id uuid primary key,stock_qty int not null,updated_at timestamptz);
  create table orders(id uuid primary key,buyer_id uuid,shop_id uuid,status text,payment_provider text,payment_state text,
    payment_url text,tradesafe_transaction_id text,shipped_at timestamptz,received_at timestamptz,created_at timestamptz default now(),updated_at timestamptz);
  create table order_items(id uuid primary key default gen_random_uuid(),order_id uuid references orders(id) on delete cascade,
    product_id uuid,variant_id uuid,quantity int,is_made_to_order boolean default false);
  create table escrow_transactions(id uuid primary key default gen_random_uuid(),order_id uuid,status text,provider_state text);
  grant all on all tables in schema public to service_role;
  insert into profiles values('${buyer}'),('${other}');
  insert into products values('${product}',5,null); insert into product_variants values('${variant}',1,null);
  insert into orders(id,buyer_id,shop_id,status,payment_provider,payment_state,payment_url,tradesafe_transaction_id) values
    ('${pendingA}','${buyer}','${shop}','pending','tradesafe','CREATED','https://pay','tx-a'),
    ('${pendingB}','${buyer}','${shop}','pending','tradesafe','checkout_created',null,null),
    ('${paid}','${buyer}','${shop}','paid','tradesafe','FUNDS_RECEIVED',null,'tx-p');
  insert into order_items(order_id,product_id,variant_id,quantity) values
    ('${pendingA}','${product}',null,2),('${pendingB}','${product}','${variant}',3),('${paid}','${product}',null,4);
  insert into order_items(order_id,product_id,variant_id,quantity,is_made_to_order) values('${pendingA}','${product}',null,7,true);
  insert into escrow_transactions(order_id,status,provider_state) values('${pendingA}','pending','CREATED'),('${paid}','held','FUNDS_RECEIVED');`);
  await db.exec(migration('20261020120000_multi_shop_checkout_groups.sql'));

  await db.exec(`reset role;set role service_role;
    insert into checkout_groups(id,buyer_id,buyer_token_id,total_due) values
      ('70000000-0000-0000-0000-000000000001','${buyer}','tok-b',507.91),
      ('70000000-0000-0000-0000-000000000002','${other}','tok-o',100);`);
  ok('a basket cannot cost less than nothing', !!(await failure(`insert into checkout_groups(buyer_id,buyer_token_id,total_due) values('${buyer}','t',-1)`)));
  ok('a new basket starts as being built', (await rows(`insert into checkout_groups(buyer_id,buyer_token_id) values('${buyer}','t') returning status`))[0].status === 'building');
  ok('an unknown status is refused', !!(await failure(`insert into checkout_groups(buyer_id,buyer_token_id,total_due,status) values('${buyer}','t',5,'paid')`)));

  await as(buyer);
  const visible = await rows(`select buyer_id from checkout_groups`);
  ok('a buyer sees only their own basket payments', visible.length === 2 && visible.every(r => r.buyer_id === buyer));
  ok('a buyer cannot read the TradeSafe account id', !!(await failure(`select buyer_token_id from checkout_groups`)));
  ok('a buyer cannot change a basket payment', !!(await failure(`update checkout_groups set status='funded'`))
    || (await rows(`select status from checkout_groups`))[0].status === 'awaiting_payment');
  ok('a buyer cannot create a basket payment', !!(await failure(`insert into checkout_groups(buyer_id,buyer_token_id,total_due) values('${buyer}','t',5)`)));
  ok('a buyer cannot undo orders', !!(await failure(`select * from cancel_unpaid_checkout_orders(array['${pendingA}'::uuid])`)));
  await as(null);
  ok('a guest sees no basket payments', !!(await failure(`select * from checkout_groups`)) || (await rows(`select * from checkout_groups`)).length === 0);

  await db.exec(`reset role;set role service_role;`);
  const undone = await rows(`select * from cancel_unpaid_checkout_orders(array['${pendingA}','${pendingB}','${paid}']::uuid[]) order by order_id`);
  ok('only the unpaid orders are undone', undone.length === 2 && undone.every(r => r.order_id !== paid));
  ok('the paid order is untouched', (await rows(`select status from orders where id='${paid}'`))[0].status === 'paid');
  ok('stock comes back for stocked lines only', (await rows(`select stock_qty from products`))[0].stock_qty === 7
    && (await rows(`select stock_qty from product_variants`))[0].stock_qty === 4);
  const cancelled = await rows(`select status,payment_state,payment_url from orders where id in ('${pendingA}','${pendingB}')`);
  ok('undone orders are cancelled with no payment link', cancelled.every(r => r.status === 'cancelled' && r.payment_state === 'STALE_CHECKOUT_CANCELLED' && r.payment_url === null));
  ok('their escrow record is cancelled', (await rows(`select status from escrow_transactions where order_id='${pendingA}'`))[0].status === 'cancelled');
  ok('undoing again changes nothing', (await rows(`select * from cancel_unpaid_checkout_orders(array['${pendingA}']::uuid[])`)).length === 0
    && (await rows(`select stock_qty from products`))[0].stock_qty === 7);

  // Stale cleanup: ordinary unpaid orders expire, basket orders are left to
  // the basket's own expiry.
  await db.exec(`insert into orders(id,buyer_id,shop_id,status,payment_provider,payment_state,tradesafe_transaction_id,created_at,checkout_group_id) values
    ('60000000-0000-0000-0000-000000000004','${buyer}','${shop}','pending','tradesafe','CREATED','tx-old',now()-interval '2 hours',null),
    ('60000000-0000-0000-0000-000000000005','${buyer}','${shop}','pending','tradesafe','CREATED','tx-basket',now()-interval '2 hours','70000000-0000-0000-0000-000000000001');`);
  const stale = await rows(`select order_id from cancel_stale_checkout_orders(30)`);
  ok('an ordinary stale checkout is still cancelled', stale.some(r => r.order_id === '60000000-0000-0000-0000-000000000004'));
  ok('a basket order is left to its basket', !stale.some(r => r.order_id === '60000000-0000-0000-0000-000000000005')
    && (await rows(`select status from orders where id='60000000-0000-0000-0000-000000000005'`))[0].status === 'pending');

  console.log(`${passed} multi-shop checkout assertions passed`);
} catch (error) { console.error(error.message); process.exitCode = 1; } finally { await db.close(); }
