import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
// Mirrors the live legacy policy set (27 Sep 2026), then applies the profile
// hardening and demo-permission removal migrations.
const db=new PGlite();
const buyer='10000000-0000-0000-0000-000000000001',maker='10000000-0000-0000-0000-000000000002',
 stranger='10000000-0000-0000-0000-000000000003',admin='10000000-0000-0000-0000-000000000004',
 shop='20000000-0000-0000-0000-000000000001',hidden='20000000-0000-0000-0000-000000000002',
 order='30000000-0000-0000-0000-000000000001',cart='40000000-0000-0000-0000-000000000001',
 draft='50000000-0000-0000-0000-000000000001',live='50000000-0000-0000-0000-000000000002';
let passed=0;
const ok=(label,value)=>{assert.ok(value,label);console.log('PASS '+label);passed++;};
async function denied(label,sql){let err;try{await db.exec(sql);}catch(e){err=e;}ok(label,!!err);}
const count=async sql=>(await db.query(sql)).rows.length;
async function asUser(id){await db.exec(`reset role;set role ${id?'authenticated':'anon'};select set_config('test.uid','${id??''}',false);`);}
const migration=name=>readFileSync(new URL(`../supabase/migrations/${name}`,import.meta.url),'utf8');
try {
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 grant usage on schema auth,public to anon,authenticated,service_role;
 create table profiles(id uuid primary key,role text not null default 'buyer',display_name text,email text,phone text,
  avatar_url text,shipping_addresses jsonb default '[]',vendor_approved_seen_at timestamptz,tradesafe_token_id text,
  admin_role text default 'none',user_role text default 'consumer',is_verified_host boolean default false,
  onboarding_status text default 'draft',onboarding_last_note text,onboarding_reviewed_at timestamptz,
  created_at timestamptz default now(),updated_at timestamptz default now());
 create function public.current_user_is_admin() returns boolean language sql stable as
  $$select exists(select 1 from public.profiles where profiles.id=auth.uid() and profiles.role='admin')$$;
 create table shops(id uuid primary key,vendor_id uuid,name text,bio text,is_active boolean default true,is_offline boolean default false,
  is_spotlight boolean default false,spotlighted_at timestamptz,created_at timestamptz default now(),updated_at timestamptz default now());
 create table orders(id uuid primary key,buyer_id uuid,shop_id uuid,status text,total numeric);
 create table order_items(id uuid primary key default gen_random_uuid(),order_id uuid,quantity int);
 create table escrow_transactions(id uuid primary key default gen_random_uuid(),order_id uuid,amount numeric);
 create table disputes(id uuid primary key default gen_random_uuid(),order_id uuid,raised_by uuid,reason text);
 create table carts(id uuid primary key,user_id uuid unique);
 create table cart_items(id uuid primary key default gen_random_uuid(),cart_id uuid,quantity int);
 create table favourites(id uuid primary key default gen_random_uuid(),user_id uuid,product_id uuid,unique(user_id,product_id));
 create table shop_follows(id uuid primary key default gen_random_uuid(),user_id uuid,shop_id uuid,unique(user_id,shop_id));
 create table shop_posts(id uuid primary key,shop_id uuid,is_published boolean);
 create table vendor_applications(id uuid primary key default gen_random_uuid(),user_id uuid,business_name text,status text default 'pending',
  reviewed_by uuid,reviewed_at timestamptz,superseded_by_application_id uuid,superseded_at timestamptz);
 create table invite_codes(id uuid primary key default gen_random_uuid(),code text,is_used boolean default false);
 do $$declare t text;begin foreach t in array array['profiles','shops','orders','order_items','escrow_transactions','disputes',
  'carts','cart_items','favourites','shop_follows','shop_posts','vendor_applications','invite_codes'] loop
  execute format('alter table %I enable row level security',t);
  execute format('grant all on %I to anon,authenticated,service_role',t);
  if t not in ('shop_posts','invite_codes') then execute format('create policy %I on %I for all using(true) with check(true)',
   'demo_'||replace(replace(t,'escrow_transactions','escrow'),'x','x')||'_all',t); end if;
 end loop;end$$;
 create policy demo_shop_posts_select on shop_posts for select using(true);
 create policy "Users can insert own profile" on profiles for insert with check(auth.uid()=id);
 create policy "Profiles are viewable by everyone" on profiles for select using(true);
 create policy "Users can update own profile" on profiles for update using(auth.uid()=id);
 create policy vendor_insert_own_shop on shops for insert with check(vendor_id=auth.uid());
 create policy "Active shops are viewable by everyone" on shops for select using(is_active=true);
 create policy "Vendors can update own shop" on shops for update using(auth.uid()=vendor_id);
 create policy "Buyers can view own orders" on orders for select using(auth.uid()=buyer_id);
 create policy vendor_select_shop_orders on orders for select using(shop_id in(select id from shops where vendor_id=auth.uid()));
 create policy vendor_update_shop_orders on orders for update using(shop_id in(select id from shops where vendor_id=auth.uid()));
 create policy "Users can view own order items" on order_items for select using(order_id in(select id from orders where buyer_id=auth.uid()));
 create policy vendor_select_order_items on order_items for select using(order_id in(select id from orders where shop_id in(select id from shops where vendor_id=auth.uid())));
 create policy "Users can view own escrow" on escrow_transactions for select using(order_id in(select id from orders where buyer_id=auth.uid()));
 create policy vendor_select_escrow on escrow_transactions for select using(order_id in(select id from orders where shop_id in(select id from shops where vendor_id=auth.uid())));
 create policy "Users can create disputes" on disputes for insert with check(auth.uid()=raised_by);
 create policy "Dispute participants can view disputes" on disputes for select using(auth.uid()=raised_by or exists(select 1 from orders o
  join shops s on s.id=o.shop_id where o.id=disputes.order_id and s.vendor_id=auth.uid()) or exists(select 1 from profiles p where p.id=auth.uid() and p.role='admin'));
 create policy "Users can create own cart" on carts for insert with check(auth.uid()=user_id);
 create policy "Users can view own cart" on carts for select using(auth.uid()=user_id);
 create policy "Users can update own cart" on carts for update using(auth.uid()=user_id);
 create policy "Users can delete cart items" on cart_items for delete using(cart_id in(select id from carts where user_id=auth.uid()));
 create policy "Users can insert cart items" on cart_items for insert with check(cart_id in(select id from carts where user_id=auth.uid()));
 create policy "Users can view own cart items" on cart_items for select using(cart_id in(select id from carts where user_id=auth.uid()));
 create policy "Users can update cart items" on cart_items for update using(cart_id in(select id from carts where user_id=auth.uid()));
 create policy "Users can delete own favourites" on favourites for delete using(auth.uid()=user_id);
 create policy "Users can insert own favourites" on favourites for insert with check(auth.uid()=user_id);
 create policy "Users can view own favourites" on favourites for select using(auth.uid()=user_id);
 create policy "Users can unfollow shops" on shop_follows for delete using(true);
 create policy "Users can follow shops" on shop_follows for insert with check(true);
 create policy "Shop follows are publicly readable" on shop_follows for select using(true);
 create policy creator_follows_insert_guard on shop_follows as restrictive for insert to anon,authenticated with check(user_id=(select auth.uid()));
 create policy creator_follows_delete_guard on shop_follows as restrictive for delete to anon,authenticated using(user_id=(select auth.uid()));
 create policy "Published posts are publicly readable" on shop_posts for select using(is_published=true);
 create policy "Vendors can update own shop posts" on shop_posts for update using(true);
 create policy creator_posts_read_guard on shop_posts as restrictive for select to anon,authenticated using((select current_user_is_admin())
  or exists(select 1 from shops s where s.id=shop_posts.shop_id and (s.vendor_id=(select auth.uid()) or (shop_posts.is_published and s.is_active and not s.is_offline))));
 create policy creator_posts_update_guard on shop_posts as restrictive for update to anon,authenticated
  using((select current_user_is_admin()) or exists(select 1 from shops s where s.id=shop_posts.shop_id and s.vendor_id=(select auth.uid())));
 create policy "Users can insert applications" on vendor_applications for insert with check(auth.uid()=user_id);
 create policy "Users can view own applications" on vendor_applications for select using(auth.uid()=user_id);
 create policy "Invite codes viewable by admin" on invite_codes for select using(true);
 create policy users_select_invite_codes on invite_codes for select using(true);
 create policy users_update_invite_codes on invite_codes for update using(true);
 insert into profiles(id,role,display_name) values('${buyer}','buyer','Buyer'),('${maker}','vendor','Maker'),('${stranger}','buyer','Stranger'),('${admin}','admin','Admin');
 insert into shops(id,vendor_id,name) values('${shop}','${maker}','Studio');
 insert into shops(id,vendor_id,name,is_active) values('${hidden}','${maker}','Paused',false);
 insert into orders values('${order}','${buyer}','${shop}','paid',500);
 insert into order_items(order_id,quantity) values('${order}',1);
 insert into escrow_transactions(order_id,amount) values('${order}',500);
 insert into disputes(order_id,raised_by,reason) values('${order}','${buyer}','Damaged');
 insert into shop_posts values('${draft}','${shop}',false),('${live}','${shop}',true);
 insert into invite_codes(code) values('SECRET');`);
 await asUser(stranger);
 ok('baseline: demo policy exposes another buyer order',await count(`select * from orders`)===1);
 await db.exec('reset role');
 await db.exec(migration('20260925092917_harden_profile_writes.sql'));
 await db.exec(migration('20260927190000_remove_demo_permissions.sql'));

 await asUser(null);
 ok('guest cannot read orders',await count(`select * from orders`)===0);
 ok('guest cannot read escrow',await count(`select * from escrow_transactions`)===0);
 ok('guest still browses active shops only',await count(`select * from shops`)===1);
 ok('guest still reads published posts only',await count(`select * from shop_posts`)===1);
 await denied('guest cannot create a shop',`insert into shops(id,vendor_id,name) values(gen_random_uuid(),null,'Fake')`);

 await asUser(stranger);
 ok('stranger cannot read another buyer order',await count(`select * from orders`)===0);
 ok('stranger cannot read order items',await count(`select * from order_items`)===0);
 ok('stranger cannot read escrow',await count(`select * from escrow_transactions`)===0);
 ok('stranger cannot read disputes',await count(`select * from disputes`)===0);
 ok('stranger cannot update orders',(await db.query(`update orders set status='refunded' returning id`)).rows.length===0);
 ok('stranger cannot delete orders',(await db.query(`delete from orders returning id`)).rows.length===0);
 await denied('stranger cannot insert orders',`insert into orders values(gen_random_uuid(),'${stranger}','${shop}','paid',1)`);
 await denied('stranger cannot forge escrow',`insert into escrow_transactions(order_id,amount) values('${order}',1)`);
 await denied('stranger cannot open dispute directly',`insert into disputes(order_id,raised_by,reason) values('${order}','${stranger}','Spam')`);
 await denied('buyer cannot create an active shop',`insert into shops(id,vendor_id,name) values(gen_random_uuid(),'${stranger}','Fake')`);
 ok('stranger cannot edit another shop',(await db.query(`update shops set name='Hacked' returning id`)).rows.length===0);
 ok('stranger cannot see drafts',await count(`select * from shop_posts where id='${draft}'`)===0);
 ok('stranger cannot edit posts',(await db.query(`update shop_posts set is_published=false returning id`)).rows.length===0);
 ok('invite codes hidden from users',await count(`select * from invite_codes`)===0);
 ok('invite codes cannot be claimed',(await db.query(`update invite_codes set is_used=true returning id`)).rows.length===0);
 await denied('follow cannot be forged for another user',`insert into shop_follows(user_id,shop_id) values('${buyer}','${shop}')`);
 await denied('favourite cannot be forged for another user',`insert into favourites(user_id,product_id) values('${buyer}',gen_random_uuid())`);
 await denied('application cannot self-approve',`insert into vendor_applications(user_id,business_name,status) values('${stranger}','X','approved')`);
 await denied('application cannot claim another user',`insert into vendor_applications(user_id,business_name) values('${buyer}','X')`);
 await db.exec(`insert into vendor_applications(user_id,business_name) values('${stranger}','My studio')`);
 ok('applicant can submit and read own pending application',await count(`select * from vendor_applications`)===1);

 await asUser(buyer);
 ok('buyer reads own order',await count(`select * from orders where id='${order}'`)===1);
 ok('buyer reads own order items and escrow',await count(`select * from order_items`)===1&&await count(`select * from escrow_transactions`)===1);
 ok('buyer reads own dispute',await count(`select * from disputes`)===1);
 ok('buyer cannot change order status',(await db.query(`update orders set status='completed' returning id`)).rows.length===0);
 await db.exec(`insert into carts values('${cart}','${buyer}') on conflict(user_id) do update set user_id=excluded.user_id`);
 await db.exec(`insert into cart_items(cart_id,quantity) values('${cart}',1)`);
 await db.exec(`update cart_items set quantity=2 where cart_id='${cart}'`);
 ok('buyer manages own cart',(await db.query(`select quantity from cart_items`)).rows[0]?.quantity===2);
 const product='60000000-0000-0000-0000-000000000001';
 await db.exec(`insert into favourites(id,user_id,product_id) values(gen_random_uuid(),'${buyer}','${product}') on conflict(id) do update set user_id=excluded.user_id`);
 ok('buyer favourite upsert works',await count(`select * from favourites`)===1);
 await db.exec(`delete from favourites where product_id='${product}'`);
 ok('buyer can remove favourite',await count(`select * from favourites`)===0);
 await db.exec(`insert into shop_follows(user_id,shop_id) values('${buyer}','${shop}')`);
 ok('buyer can follow and unfollow',(await db.query(`delete from shop_follows where shop_id='${shop}' returning id`)).rows.length===1);
 await db.exec(`update profiles set display_name='Buyer B' where id='${buyer}'`);
 await denied('buyer cannot become admin',`update profiles set role='admin' where id='${buyer}'`);

 await asUser(stranger);
 ok('stranger cannot read buyer cart',await count(`select * from cart_items`)===0);
 ok('stranger cannot edit buyer cart',(await db.query(`update cart_items set quantity=99 returning id`)).rows.length===0);

 await asUser(maker);
 ok('maker reads orders for own shop',await count(`select * from orders`)===1);
 ok('maker reads own order items, escrow and dispute',await count(`select * from order_items`)===1&&await count(`select * from escrow_transactions`)===1&&await count(`select * from disputes`)===1);
 ok('maker cannot set order status directly',(await db.query(`update orders set status='completed' returning id`)).rows.length===0);
 ok('maker sees own inactive shop',await count(`select * from shops where id='${hidden}'`)===1);
 await db.exec(`update shops set name='Studio Two',bio='New',is_offline=true where id='${shop}'`);
 ok('maker edits shop details and offline mode',(await db.query(`select name from shops where id='${shop}'`)).rows[0].name==='Studio Two');
 await db.exec(`update shops set is_offline=false where id='${shop}'`);
 await denied('maker cannot self-spotlight',`update shops set is_spotlight=true where id='${shop}'`);
 await denied('maker cannot reactivate suspended shop',`update shops set is_active=true where id='${hidden}'`);
 await denied('maker cannot transfer shop',`update shops set vendor_id='${stranger}' where id='${shop}'`);
 ok('maker reads own draft',await count(`select * from shop_posts where id='${draft}'`)===1);
 ok('maker edits own post',(await db.query(`update shop_posts set is_published=true where id='${draft}' returning id`)).rows.length===1);

 await asUser(admin);
 ok('admin reads drafts and invite codes',await count(`select * from shop_posts`)===2&&await count(`select * from invite_codes`)===1);

 await db.exec(`reset role;set role service_role;
  update shops set is_spotlight=true,is_active=true where id='${hidden}';
  update orders set status='completed' where id='${order}';
  insert into disputes(order_id,raised_by,reason) values('${order}','${buyer}','Server opened');`);
 ok('trusted server keeps status, spotlight and dispute control',(await db.query(`select status from orders`)).rows[0].status==='completed'&&await count(`select * from shops where is_spotlight`)===1);
 console.log(`${passed} ownership policy assertions passed`);
} finally {await db.close();}
