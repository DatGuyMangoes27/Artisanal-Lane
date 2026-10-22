// Isolated PostgreSQL tests for 20261022100000_hide_unsubscribed_shops.sql;
// never connects to the live project. Mirrors the live policies on shops,
// products, orders, order_items, chat_threads, shop_posts and shop_stories
// before applying the migration.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const id = n => `10000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const sid = n => `20000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const pid = n => `30000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const postId = n => `40000000-0000-0000-0000-${String(n).padStart(12, '0')}`;

// Vendors / shops: 1 active, 2 unsubscribed (no row), 3 in 5-day grace,
// 4 cancelled but paid through, 5 cancelled + expired, 6 past_due in grace,
// 7 active beyond grace, 8 inactive shop with active subscription.
const vActive = id(1), vNone = id(2), vGrace = id(3), vCancelledPaid = id(4), vCancelledOver = id(5),
  vPastDue = id(6), vLapsed = id(7), vInactiveShop = id(8);
const admin = id(20), buyer = id(21), stranger = id(22), chatter = id(23);
const shop = { active: sid(1), none: sid(2), grace: sid(3), cancelledPaid: sid(4), cancelledOver: sid(5),
  pastDue: sid(6), lapsed: sid(7), inactive: sid(8) };
const listedShops = [shop.active, shop.grace, shop.cancelledPaid, shop.pastDue].sort();

let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); passed++; };
async function failure(sql) { try { await db.exec(sql); } catch (e) { return e; } return null; }
const rows = async sql => (await db.query(sql)).rows;
const ids = async sql => (await rows(sql)).map(r => r.id).sort();
const migration = name => readFileSync(new URL(`../supabase/migrations/${name}`, import.meta.url), 'utf8');
async function as(uid, role) {
  await db.exec(`reset role;set role ${role ?? (uid ? 'authenticated' : 'anon')};select set_config('test.uid','${uid ?? ''}',false);`);
}
const same = (a, b) => JSON.stringify([...a].sort()) === JSON.stringify([...b].sort());

try {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  grant usage on schema auth,public to anon,authenticated,service_role;

  create table profiles(id uuid primary key,role text not null default 'buyer');
  create function public.current_user_is_admin() returns boolean language sql stable as $$
    select exists(select 1 from public.profiles where profiles.id=auth.uid() and profiles.role='admin')$$;

  create table vendor_subscriptions(vendor_id uuid primary key,status text not null default 'inactive',
    current_period_end timestamptz,cancelled_at timestamptz,updated_at timestamptz default now());
  create table shops(id uuid primary key,vendor_id uuid,name text not null,is_active boolean default true,
    is_offline boolean default false,is_spotlight boolean default false);
  create table categories(id uuid primary key,name text);create table subcategories(id uuid primary key,name text);
  grant select on categories,subcategories to anon,authenticated;
  create table products(id uuid primary key,shop_id uuid references shops(id),title text,is_published boolean default true,
    archived_at timestamptz,stock_qty int default 1,description text,tags text[] default '{}',fulfillment_mode text default 'stocked',
    category_id uuid,subcategory_id uuid,created_at timestamptz default now());
  create table orders(id uuid primary key default gen_random_uuid(),buyer_id uuid,shop_id uuid references shops(id),status text default 'paid');
  create table order_items(id uuid primary key default gen_random_uuid(),order_id uuid references orders(id),product_id uuid references products(id),quantity int default 1);
  create table chat_threads(id uuid primary key default gen_random_uuid(),shop_id uuid references shops(id),buyer_id uuid,vendor_id uuid);
  create table shop_posts(id uuid primary key default gen_random_uuid(),shop_id uuid references shops(id),caption text default '',
    media_urls jsonb default '[]',is_published boolean default true,product_ids uuid[] default '{}',comments_enabled boolean default true,
    hide_like_count boolean default false,scheduled_for timestamptz,format text default 'photo',step_captions jsonb default '[]',
    removed_at timestamptz,published_at timestamptz default now());
  create table shop_stories(id uuid primary key default gen_random_uuid(),shop_id uuid references shops(id),media_path text,
    expires_at timestamptz default now()+interval '1 day');

  alter table vendor_subscriptions enable row level security;alter table shops enable row level security;
  alter table products enable row level security;alter table orders enable row level security;
  alter table order_items enable row level security;alter table chat_threads enable row level security;
  alter table shop_posts enable row level security;alter table shop_stories enable row level security;
  alter table profiles enable row level security;
  create policy profiles_read on profiles for select using (true);
  grant select on profiles to anon,authenticated;
  grant select,insert,update,delete on vendor_subscriptions,shops,products,orders,order_items,chat_threads,shop_posts,shop_stories
    to anon,authenticated,service_role;

  -- Live policies before the migration (pg_policies on byckurabenbunsbrzcpl, 2026-10-22).
  create policy "Vendors can view own subscriptions" on vendor_subscriptions for select using (auth.uid()=vendor_id);
  create policy "Admins can view vendor subscriptions" on vendor_subscriptions for select using (public.current_user_is_admin());
  create policy "Active shops are viewable by everyone" on shops for select using (is_active=true);
  create policy shops_owner_select on shops for select to authenticated using (vendor_id=(select auth.uid()));
  create policy "Vendors can update own shop" on shops for update using (auth.uid()=vendor_id);
  create policy "Published products viewable by everyone" on products for select using (is_published=true and archived_at is null);
  create policy vendor_select_own_products on products for select using (shop_id in (select shops.id from shops where shops.vendor_id=auth.uid()));
  create policy "Buyers can view own orders" on orders for select using (auth.uid()=buyer_id);
  create policy vendor_select_shop_orders on orders for select using (shop_id in (select shops.id from shops where shops.vendor_id=auth.uid()));
  create policy "Users can view own order items" on order_items for select using (order_id in (select orders.id from orders where orders.buyer_id=auth.uid()));
  create policy vendor_select_order_items on order_items for select using (order_id in (select orders.id from orders
    where orders.shop_id in (select shops.id from shops where shops.vendor_id=auth.uid())));
  create policy "Participants can view chat threads" on chat_threads for select
    using (buyer_id=auth.uid() or vendor_id=auth.uid() or public.current_user_is_admin());
  create policy "Published posts are publicly readable" on shop_posts for select using (is_published=true);
  create policy shop_posts_owner_select on shop_posts for select to authenticated using ((select public.current_user_is_admin())
    or exists(select 1 from shops s where s.id=shop_posts.shop_id and s.vendor_id=(select auth.uid())));
  create policy vendor_insert_posts on shop_posts for insert with check (shop_id in (select shops.id from shops where shops.vendor_id=auth.uid()));
  create policy vendor_update_posts on shop_posts for update using (shop_id in (select shops.id from shops where shops.vendor_id=auth.uid()));
  create policy creator_posts_read_guard on shop_posts as restrictive for select to anon,authenticated
    using ((select public.current_user_is_admin()) or exists(select 1 from shops s where s.id=shop_id
      and (s.vendor_id=(select auth.uid()) or (is_published and s.is_active and not s.is_offline))));
  create policy creator_posts_insert_guard on shop_posts as restrictive for insert to anon,authenticated
    with check ((select public.current_user_is_admin()) or exists(select 1 from shops s where s.id=shop_id and s.vendor_id=(select auth.uid())));
  create policy creator_posts_update_guard on shop_posts as restrictive for update to anon,authenticated
    using ((select public.current_user_is_admin()) or exists(select 1 from shops s where s.id=shop_id and s.vendor_id=(select auth.uid())))
    with check ((select public.current_user_is_admin()) or exists(select 1 from shops s where s.id=shop_id and s.vendor_id=(select auth.uid())));
  create policy stories_live_read on shop_stories for select to anon,authenticated
    using (expires_at>now() and exists(select 1 from shops s where s.id=shop_id
      and ((s.is_active and not s.is_offline) or s.vendor_id=(select auth.uid()))));`);
  await db.exec(migration('20261014090000_subscription_payment_grace.sql'));

  await db.exec(`insert into profiles(id,role) values
    ('${vActive}','vendor'),('${vNone}','vendor'),('${vGrace}','vendor'),('${vCancelledPaid}','vendor'),('${vCancelledOver}','vendor'),
    ('${vPastDue}','vendor'),('${vLapsed}','vendor'),('${vInactiveShop}','vendor'),('${admin}','admin'),('${buyer}','buyer'),
    ('${stranger}','buyer'),('${chatter}','buyer');
  insert into vendor_subscriptions(vendor_id,status,current_period_end,cancelled_at) values
    ('${vActive}','active',now()+interval '20 days',null),
    ('${vGrace}','active',now()-interval '3 days',null),
    ('${vCancelledPaid}','cancelled',now()+interval '10 days',now()-interval '1 day'),
    ('${vCancelledOver}','cancelled',now()-interval '1 day',now()-interval '20 days'),
    ('${vPastDue}','past_due',now()-interval '2 days',null),
    ('${vLapsed}','active',now()-interval '30 days',null),
    ('${vInactiveShop}','active',now()+interval '20 days',null);
  insert into shops(id,vendor_id,name,is_active) values
    ('${shop.active}','${vActive}','Active',true),('${shop.none}','${vNone}','Never subscribed',true),
    ('${shop.grace}','${vGrace}','Grace',true),('${shop.cancelledPaid}','${vCancelledPaid}','Cancelled paid',true),
    ('${shop.cancelledOver}','${vCancelledOver}','Cancelled over',true),('${shop.pastDue}','${vPastDue}','Past due',true),
    ('${shop.lapsed}','${vLapsed}','Lapsed',true),('${shop.inactive}','${vInactiveShop}','Inactive',false);
  insert into products(id,shop_id,title) select ('30000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
    ('20000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'Product '||n from generate_series(1,8) n;
  insert into products(id,shop_id,title) values ('${pid(102)}','${shop.none}','Second unsubscribed product');
  insert into shop_posts(id,shop_id,caption) select ('40000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
    ('20000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'Post '||n from generate_series(1,8) n;
  insert into shop_stories(shop_id,media_path) values ('${shop.active}','a.jpg'),('${shop.none}','b.jpg');
  insert into orders(id,buyer_id,shop_id) values ('50000000-0000-0000-0000-000000000001','${buyer}','${shop.none}');
  insert into order_items(order_id,product_id) values ('50000000-0000-0000-0000-000000000001','${pid(2)}');
  insert into chat_threads(shop_id,buyer_id,vendor_id) values ('${shop.lapsed}','${chatter}','${vLapsed}');`);

  await db.exec(migration('20261022090000_search_buyer_products.sql'));
  await db.exec(migration('20261022100000_hide_unsubscribed_shops.sql'));

  // ── Listing flag ──────────────────────────────────────────────────────
  ok('backfill lists only active shops with an active/grace subscription',
    same(await ids(`select id from shops where is_publicly_listed`), listedShops));

  // ── Guests ────────────────────────────────────────────────────────────
  await as(null);
  ok('guest: unsubscribed, lapsed, cancelled-expired and inactive shops hidden; active/grace/paid-through/past_due visible',
    same(await ids(`select id from shops`), listedShops));
  ok('guest: products only from listed shops',
    same((await rows(`select shop_id from products`)).map(r => r.shop_id), listedShops));
  ok('guest: a hidden shop page reached by link returns nothing', (await rows(`select id from shops where id='${shop.none}'`)).length === 0);
  ok('guest: a hidden product reached by link returns nothing', (await rows(`select id from products where id='${pid(2)}'`)).length === 0);
  ok('guest: feed only shows posts from listed shops',
    same((await rows(`select shop_id from shop_posts`)).map(r => r.shop_id), listedShops));
  ok('guest: stories from unsubscribed shops are hidden', same((await rows(`select shop_id from shop_stories`)).map(r => r.shop_id), [shop.active]));
  ok('guest: search_buyer_products RPC only returns products of listed shops',
    same((await rows(`select shop_id from public.search_buyer_products('product', 60)`)).map(r => r.shop_id), listedShops));
  ok('guest: product embed with an inner shop join drops hidden shops',
    (await rows(`select p.id from products p join shops s on s.id=p.shop_id where s.id='${shop.none}'`)).length === 0);

  // ── Buyer without history ─────────────────────────────────────────────
  await as(stranger);
  ok('buyer: same public view as a guest', same(await ids(`select id from shops`), listedShops));
  ok('buyer: search RPC skips unsubscribed shops',
    same((await rows(`select shop_id from public.search_buyer_products('product', 60)`)).map(r => r.shop_id), listedShops));
  ok('buyer: no hidden products', (await rows(`select id from products where shop_id not in (${listedShops.map(s => `'${s}'`).join(',')})`)).length === 0);

  // ── Buyer with order history from an unsubscribed shop ────────────────
  await as(buyer);
  ok('buyer order history: order still readable', (await rows(`select id from orders`)).length === 1);
  const history = await rows(`select o.id, s.name shop_name, p.title from orders o
    join order_items oi on oi.order_id=o.id left join products p on p.id=oi.product_id left join shops s on s.id=o.shop_id`);
  ok('buyer order history: shop name and product title still resolve', history.length === 1
    && history[0].shop_name === 'Never subscribed' && history[0].title === 'Product 2');
  ok('buyer order history: other products of that shop stay hidden',
    (await rows(`select id from products where id='${pid(102)}'`)).length === 0);
  ok('buyer order history: the shop is still unlisted for public list filters',
    (await rows(`select id from shops where is_publicly_listed and id='${shop.none}'`)).length === 0);
  ok('buyer order history: unsubscribed shop posts stay out of the feed',
    (await rows(`select id from shop_posts where shop_id='${shop.none}'`)).length === 0);

  // ── Chat participant ──────────────────────────────────────────────────
  await as(chatter);
  ok('chat participant: thread still resolves the shop name',
    (await rows(`select s.name from chat_threads t join shops s on s.id=t.shop_id`))[0]?.name === 'Lapsed');

  // ── Unsubscribed vendor ───────────────────────────────────────────────
  await as(vNone);
  ok('unsubscribed vendor: sees own shop', (await rows(`select id from shops where id='${shop.none}'`)).length === 1);
  ok('unsubscribed vendor: sees all own products',
    (await rows(`select id from products where shop_id='${shop.none}'`)).length === 2);
  ok('unsubscribed vendor: sees own posts', (await rows(`select id from shop_posts where shop_id='${shop.none}'`)).length === 1);
  ok('unsubscribed vendor: sees own orders', (await rows(`select id from orders`)).length === 1);
  ok('unsubscribed vendor: sees own stories', (await rows(`select id from shop_stories where shop_id='${shop.none}'`)).length === 1);

  const blocked = await failure(`insert into shop_posts(shop_id,caption,is_published) values('${shop.none}','Free advert',true)`);
  ok('unsubscribed vendor: cannot publish a feed post', !!blocked && /Subscribe to post to the feed/.test(blocked.message));
  await db.exec(`insert into shop_posts(id,shop_id,caption,is_published) values('${postId(200)}','${shop.none}','Draft',false)`);
  ok('unsubscribed vendor: can save a draft', (await rows(`select id from shop_posts where id='${postId(200)}'`)).length === 1);
  ok('unsubscribed vendor: cannot publish a draft',
    !!(await failure(`update shop_posts set is_published=true where id='${postId(200)}'`)));
  ok('unsubscribed vendor: cannot edit the content of an old published post',
    !!(await failure(`update shop_posts set caption='New offer' where id='${postId(2)}'`)));
  await db.exec(`update shop_posts set comments_enabled=false where id='${postId(2)}'`);
  ok('unsubscribed vendor: settings-only change on an old post is allowed',
    (await rows(`select comments_enabled from shop_posts where id='${postId(2)}'`))[0].comments_enabled === false);
  await db.exec(`update shop_posts set is_published=false where id='${postId(2)}'`);
  ok('unsubscribed vendor: can unpublish', (await rows(`select is_published from shop_posts where id='${postId(2)}'`))[0].is_published === false);
  await db.exec(`update shops set is_publicly_listed=true, name='Renamed' where id='${shop.none}'`);
  ok('unsubscribed vendor: cannot list their own shop by setting the flag',
    (await rows(`select is_publicly_listed, name from shops where id='${shop.none}'`))[0].is_publicly_listed === false);
  ok('subscription status function is not callable to probe other vendors',
    !!(await failure(`select public.shop_should_be_publicly_listed(true,'${vActive}')`)));

  // ── Website vendor actions run as service_role ────────────────────────
  await as(null, 'service_role');
  ok('service-role post publish for an unsubscribed shop is blocked too',
    !!(await failure(`insert into shop_posts(shop_id,caption,is_published) values('${shop.none}','Via website',true)`)));

  // ── Subscribed vendors ────────────────────────────────────────────────
  await as(vActive);
  await db.exec(`insert into shop_posts(shop_id,caption,is_published) values('${shop.active}','New work',true)`);
  ok('subscribed vendor: can publish', (await rows(`select id from shop_posts where caption='New work'`)).length === 1);
  await as(vGrace);
  await db.exec(`insert into shop_posts(shop_id,caption,is_published) values('${shop.grace}','Grace post',true)`);
  ok('vendor in payment grace: can publish', (await rows(`select id from shop_posts where caption='Grace post'`)).length === 1);
  await as(vLapsed);
  ok('vendor lapsed beyond grace: cannot publish',
    !!(await failure(`insert into shop_posts(shop_id,caption,is_published) values('${shop.lapsed}','Lapsed post',true)`)));

  // ── Admin ─────────────────────────────────────────────────────────────
  await as(admin);
  ok('admin: sees every shop (leads)', (await rows(`select id from shops`)).length === 8);
  ok('admin: sees every product', (await rows(`select id from products`)).length === 9);
  ok('admin: sees every post', (await rows(`select id from shop_posts where shop_id='${shop.none}'`)).length === 2);

  // ── Subscription changes take effect immediately ──────────────────────
  await db.exec(`reset role;insert into vendor_subscriptions(vendor_id,status,current_period_end) values('${vNone}','active',now()+interval '30 days')`);
  await as(null);
  ok('subscribing lists the shop immediately', (await rows(`select id from shops where id='${shop.none}'`)).length === 1);
  ok('subscribing shows its products immediately', (await rows(`select id from products where shop_id='${shop.none}'`)).length === 2);
  await db.exec(`reset role;update vendor_subscriptions set status='cancelled',cancelled_at=now(),current_period_end=now()-interval '1 minute' where vendor_id='${vNone}'`);
  await as(null);
  ok('an ended subscription unlists the shop immediately', (await rows(`select id from shops where id='${shop.none}'`)).length === 0);
  await db.exec(`reset role;delete from vendor_subscriptions where vendor_id='${vActive}'`);
  await as(null);
  ok('deleting a subscription unlists the shop', (await rows(`select id from shops where id='${shop.active}'`)).length === 0);
  await db.exec(`reset role;insert into vendor_subscriptions(vendor_id,status,current_period_end) values('${vActive}','active',now()+interval '20 days')`);

  // ── Expiry by time passing (cron job) ─────────────────────────────────
  await db.exec(`reset role;alter table shops disable trigger set_shop_public_listing;
    update shops set is_publicly_listed=true where id='${shop.lapsed}';
    alter table shops enable trigger set_shop_public_listing;`);
  ok('refresh job fixes a stale listing', (await rows(`select public.refresh_shop_public_listings() n`))[0].n === 1
    && (await rows(`select is_publicly_listed from shops where id='${shop.lapsed}'`))[0].is_publicly_listed === false);
  ok('refresh job is a no-op when nothing changed', (await rows(`select public.refresh_shop_public_listings() n`))[0].n === 0);
  await as(stranger);
  ok('members cannot run the refresh job', !!(await failure(`select public.refresh_shop_public_listings()`)));

  // ── Reactivating a shop (admin) uses the subscription ─────────────────
  await db.exec(`reset role;update shops set is_active=true where id='${shop.inactive}'`);
  ok('reactivated shop with an active subscription becomes listed',
    (await rows(`select is_publicly_listed from shops where id='${shop.inactive}'`))[0].is_publicly_listed === true);

  console.log(`${passed} unsubscribed-shop visibility assertions passed`);
} catch (error) { console.error(error); process.exitCode = 1; } finally { await db.close(); }
