// Isolated database only: no remote credentials or project writes.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
let checks = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); checks++; };
const titles = async (query, limit = 60) =>
  (await db.query('select title from public.search_buyer_products($1, $2)', [query, limit])).rows.map((r) => r.title);

try {
  await db.exec(`create role anon; create role authenticated;
  create table public.shops(id text primary key, name text not null, is_active boolean not null default true);
  create table public.categories(id text primary key, name text not null);
  create table public.subcategories(id text primary key, name text not null);
  create table public.products(
    id text primary key, shop_id text not null references public.shops(id),
    category_id text, subcategory_id text, title text not null, description text,
    tags text[] not null default '{}', is_published boolean not null default true,
    archived_at timestamptz, stock_qty int not null default 1,
    fulfillment_mode text not null default 'stocked', created_at timestamptz not null);
  insert into public.shops values
    ('knit','KnitbyNic',true),('clay','h.of.clay',true),('bottles','Vintage Art Bottles',true),
    ('copper','Copper & Co',true),('ring','Rings by Lu',true),('closed','Closed Rings',false);
  insert into public.categories values ('jew','Jewellery'),('home','Home');
  insert into public.subcategories values ('rings','Rings'),('ear','Earrings'),('neck','Necklaces');
  insert into public.products(id,shop_id,category_id,subcategory_id,title,description,tags,created_at) values
    ('santa','knit','home',null,'Santa tree hanger - white','Hangs from strings on your tree','{}','2026-10-20'),
    ('hoops','clay','jew','ear','Sweet Panda Hoops','Cute clay earrings','{}','2026-10-19'),
    ('sunflower','bottles','home',null,'Sunflower soul','Pairs well with a necklace','{}','2026-10-21'),
    ('pendant','copper','jew','neck','Copper Pendant Necklace','Hand formed','{}','2026-09-01'),
    ('silver','copper','jew','rings','Silver Stacking Ring','Sterling band','{}','2026-08-01'),
    ('tagged','clay','jew',null,'Moon band','Polished','{rings,moon}','2026-07-01'),
    ('shopmatch','ring','home',null,'Tea towel','Linen','{}','2026-06-01'),
    ('spring','clay','home',null,'Spring wreath','Seasonal','{}','2026-10-22'),
    ('draft','copper','jew','rings','Draft Ring','x','{}','2026-10-22'),
    ('hidden','closed','jew','rings','Hidden Ring','x','{}','2026-10-22'),
    ('sold','copper','jew','rings','Sold out ring','x','{}','2026-10-22');
  update public.products set is_published=false where id='draft';
  update public.products set stock_qty=0 where id='sold';`);
  await db.exec(readFileSync(new URL('../supabase/migrations/20261022090000_search_buyer_products.sql', import.meta.url), 'utf8'));

  const rings = await titles('rings');
  ok('"rings" skips words that merely contain it (strings, earrings, spring)',
    !rings.includes('Santa tree hanger - white') && !rings.includes('Sweet Panda Hoops') && !rings.includes('Spring wreath'));
  ok('"rings" ranks a title match first (plural-insensitive)', rings[0] === 'Silver Stacking Ring');
  ok('"rings" then tag/subcategory, then shop name', rings.join('|') === 'Silver Stacking Ring|Moon band|Tea towel');

  const neckla = await titles('neckla');
  ok('"neckla" prefix-matches necklace with the title match first', neckla[0] === 'Copper Pendant Necklace');
  ok('description-only match comes last', neckla.at(-1) === 'Sunflower soul' && neckla.length === 2);

  ok('every query word must match', (await titles('copper ring')).join('|') === 'Silver Stacking Ring');
  ok('multi-word title match', (await titles('copper necklace'))[0] === 'Copper Pendant Necklace');
  ok('drafts, inactive shops and sold-out stock never appear',
    !(await titles('ring')).some((t) => ['Draft Ring', 'Hidden Ring', 'Sold out ring'].includes(t)));
  ok('empty query returns nothing', (await titles('  ')).length === 0);
  ok('punctuation-only query returns nothing', (await titles('%,()')).length === 0);
  ok('limit is respected', (await titles('ring', 1)).length === 1);
  ok('singular helper handles es/ies plurals',
    (await db.query(`select public.search_singular('boxes') a, public.search_singular('accessories') b, public.search_singular('glass') c`)).rows[0].a === 'box');
  console.log(`${checks} product search assertions passed`);
} finally { await db.close(); }
