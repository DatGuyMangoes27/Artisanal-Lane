// Isolated PostgreSQL tests for the Bob Go migrations; never connects to the
// live project. Mirrors the live orders policies (buyers/vendors read only,
// after 20260927190000_remove_demo_permissions), applies the foundation
// migration (live as 20260817132555) and then
// 20260929120000_bobgo_tracking_and_cancellation.sql twice (it must be
// re-runnable).
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const buyer = '10000000-0000-0000-0000-000000000001', maker = '10000000-0000-0000-0000-000000000002',
  otherMaker = '10000000-0000-0000-0000-000000000003', stranger = '10000000-0000-0000-0000-000000000004',
  shop = '20000000-0000-0000-0000-000000000001', otherShop = '20000000-0000-0000-0000-000000000002',
  order = '30000000-0000-0000-0000-000000000001', otherOrder = '30000000-0000-0000-0000-000000000002',
  quote = '40000000-0000-0000-0000-000000000001';
let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); passed++; };
async function failure(sql) { try { await db.exec(sql); } catch (e) { return e; } return null; }
async function denied(label, sql) { ok(label, !!(await failure(sql))); }
const rows = async sql => (await db.query(sql)).rows;
const migration = name => readFileSync(new URL(`../supabase/migrations/${name}`, import.meta.url), 'utf8');
async function as(id) { await db.exec(`reset role;set role ${id ? 'authenticated' : 'anon'};select set_config('test.uid','${id ?? ''}',false);`); }
async function asService() { await db.exec(`reset role;set role service_role;`); }

try {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  grant usage on schema auth,public to anon,authenticated,service_role;
  create table profiles(id uuid primary key,role text not null default 'buyer');
  create table shops(id uuid primary key,vendor_id uuid,name text);
  create table products(id uuid primary key default gen_random_uuid(),shop_id uuid,title text,price numeric default 0);
  create table orders(id uuid primary key,buyer_id uuid references profiles(id),shop_id uuid references shops(id),
    status text not null default 'pending',shipping_method text,shipping_cost numeric default 0,tracking_number text,
    tracking_url text,paid_at timestamptz,updated_at timestamptz default now());
  do $$declare t text;begin foreach t in array array['profiles','shops','products','orders'] loop
    execute format('alter table %I enable row level security',t);
    execute format('grant all on %I to anon,authenticated,service_role',t); end loop;end$$;
  alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
  create policy profiles_read on profiles for select using(true);
  create policy shops_read on shops for select using(true);
  create policy products_owner on products for all to authenticated
    using(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()))
    with check(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()));
  create policy "Buyers can view own orders" on orders for select using(auth.uid()=buyer_id);
  create policy vendor_select_shop_orders on orders for select
    using(shop_id in (select shops.id from shops where shops.vendor_id=auth.uid()));
  insert into profiles(id,role) values('${buyer}','buyer'),('${maker}','vendor'),('${otherMaker}','vendor'),('${stranger}','buyer');
  insert into shops(id,vendor_id,name) values('${shop}','${maker}','Clay Studio'),('${otherShop}','${otherMaker}','Wood Shed');`);

  await db.exec(migration('20260817150500_add_bobgo_shipping_foundation.sql'));
  await db.exec(migration('20260929120000_bobgo_tracking_and_cancellation.sql'));
  ok('tracking migration re-applies cleanly (idempotent)',
    !(await failure(migration('20260929120000_bobgo_tracking_and_cancellation.sql'))));

  // ── Schema ──
  await asService();
  await db.exec(`insert into bobgo_shipping_quotes(id,buyer_id,shop_id,rate_request_id,request_snapshot)
      values('${quote}','${buyer}','${shop}',1,'{}');
    insert into orders(id,buyer_id,shop_id,status,shipping_method,shipping_cost,bobgo_quote_id)
      values('${order}','${buyer}','${shop}','paid','bobgo_door_to_door',95,'${quote}'),
            ('${otherOrder}','${stranger}','${otherShop}','paid','pargo',65,null);`);
  const fresh = (await rows(`select bobgo_booking_state,bobgo_booking_attempts,bobgo_tracking_events,bobgo_booking_started_at
    from orders where id='${order}'`))[0];
  ok('new orders start not_requested with zero attempts and no events',
    fresh.bobgo_booking_state === 'not_requested' && fresh.bobgo_booking_attempts === 0 &&
    Array.isArray(fresh.bobgo_tracking_events) && fresh.bobgo_tracking_events.length === 0 &&
    fresh.bobgo_booking_started_at === null);
  ok('cancelled is an allowed booking state',
    !(await failure(`update orders set bobgo_booking_state='cancelled' where id='${otherOrder}'`)));
  await denied('unknown booking states are rejected',
    `update orders set bobgo_booking_state='lost_in_space' where id='${order}'`);
  await denied('unknown shipping methods are rejected',
    `update orders set shipping_method='teleport' where id='${order}'`);
  const indexes = (await rows(`select indexname from pg_indexes where tablename='orders'`)).map(r => r.indexname);
  ok('tracking, open-shipment, pending and stuck-booking indexes exist',
    ['orders_bobgo_tracking_number_idx', 'orders_bobgo_open_shipments_idx', 'orders_bobgo_pending_booking_idx',
      'orders_bobgo_stuck_booking_idx'].every(name => indexes.includes(name)));

  // Booking claim is a compare-and-set: only one caller wins.
  const claim = `update orders set bobgo_booking_state='booking',bobgo_booking_started_at=now()
    where id='${order}' and status='paid' and bobgo_booking_state in ('not_requested','failed')
      and bobgo_shipment_id is null returning id`;
  ok('first booking claim wins', (await rows(claim)).length === 1);
  ok('second concurrent claim loses', (await rows(claim)).length === 0);
  await db.exec(`update orders set bobgo_booking_state='booked',bobgo_shipment_id='77',tracking_number='UAS77'
    where id='${order}' and bobgo_booking_state='booking'`);
  await db.exec(`update orders set bobgo_booking_state='not_requested' where id='${otherOrder}'`);

  // ── Orders stay read-only for users; Bob Go columns are server-written ──
  await as(buyer);
  ok('buyer reads courier state on their own order',
    (await rows(`select bobgo_booking_state,tracking_number from orders where id='${order}'`))[0]?.tracking_number === 'UAS77');
  ok('buyer cannot see another buyer\'s order', (await rows(`select 1 from orders where id='${otherOrder}'`)).length === 0);
  await db.exec(`update orders set bobgo_booking_state='failed',bobgo_shipment_id=null,tracking_number='FAKE' where id='${order}'`);
  await as(maker);
  ok('vendor reads their shop order', (await rows(`select 1 from orders where id='${order}'`)).length === 1);
  await db.exec(`update orders set tracking_number='VENDOR-EDIT',bobgo_booking_state='not_requested',status='shipped' where id='${order}'`);
  await as(otherMaker);
  ok('another vendor cannot see the order', (await rows(`select 1 from orders where id='${order}'`)).length === 0);
  await as(null);
  ok('guests see no orders', (await rows(`select 1 from orders`)).length === 0);
  await asService();
  const after = (await rows(`select status,bobgo_booking_state,tracking_number,bobgo_shipment_id from orders where id='${order}'`))[0];
  ok('buyer and vendor updates changed nothing (no update policy)',
    after.status === 'paid' && after.bobgo_booking_state === 'booked' && after.tracking_number === 'UAS77' &&
    after.bobgo_shipment_id === '77');

  // ── Saved quotes are server-only ──
  await as(buyer);
  await denied('buyers cannot read saved quotes (prices are verified server-side)', `select * from bobgo_shipping_quotes`);
  await denied('buyers cannot forge a quote', `insert into bobgo_shipping_quotes(buyer_id,shop_id,rate_request_id,request_snapshot)
    values('${buyer}','${shop}',2,'{}')`);
  await denied('buyers cannot change a quoted price', `update bobgo_shipping_quotes set rates='[{"amount":1}]'`);
  await as(null);
  await denied('guests cannot read saved quotes', `select * from bobgo_shipping_quotes`);

  // ── Private collection addresses ──
  const profileValues = (shopId) => `('${shopId}','Thandi','t@example.com','0821234567','1 Clay St','Woodstock','Cape Town','Western Cape','7925',true)`;
  const profileInsert = (shopId) => `insert into shop_fulfillment_profiles(shop_id,contact_full_name,contact_email,contact_phone,
    street_address,local_area,city,province,postal_code,bobgo_enabled) values ${profileValues(shopId)}`;
  await as(maker);
  ok('vendor saves their own collection address', !(await failure(profileInsert(shop))));
  await denied('vendor cannot create a collection address for another shop', profileInsert(otherShop));
  ok('vendor reads their own collection address', (await rows(`select 1 from shop_fulfillment_profiles`)).length === 1);
  await as(otherMaker);
  ok('other vendors cannot read the collection address', (await rows(`select 1 from shop_fulfillment_profiles`)).length === 0);
  await db.exec(`update shop_fulfillment_profiles set street_address='hijack' where shop_id='${shop}'`);
  await as(buyer);
  ok('buyers cannot read collection addresses', (await rows(`select 1 from shop_fulfillment_profiles`)).length === 0);
  await as(null);
  await denied('guests cannot read collection addresses', `select * from shop_fulfillment_profiles`);
  await asService();
  ok('other vendor update did not change the address',
    (await rows(`select street_address from shop_fulfillment_profiles where shop_id='${shop}'`))[0].street_address === '1 Clay St');
  await denied('only South African collection addresses', `update shop_fulfillment_profiles set country_code='US'`);
  await denied('parcel measurements must be positive', `insert into products(shop_id,title,shipping_weight_kg) values('${shop}','Mug',0)`);

  console.log(`${passed} Bob Go policy assertions passed`);
} catch (error) { console.error(error.message); process.exitCode = 1; } finally { await db.close(); }
