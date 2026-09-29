import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
// Applies the profile hardening, private readers and both privacy stages in
// order, checking guest, member, vendor and server behaviour at each stage.
const db=new PGlite();
const buyer='10000000-0000-0000-0000-000000000001',maker='10000000-0000-0000-0000-000000000002',
 stranger='10000000-0000-0000-0000-000000000003',fresh='10000000-0000-0000-0000-000000000004',
 shop='20000000-0000-0000-0000-000000000001',order='30000000-0000-0000-0000-000000000001';
let passed=0;
const ok=(label,value)=>{assert.ok(value,label);console.log('PASS '+label);passed++;};
async function denied(label,sql){let err;try{await db.exec(sql);}catch(e){err=e;}ok(label,!!err);}
async function works(label,sql){await db.exec(sql);ok(label,true);}
const rows=async sql=>(await db.query(sql)).rows;
async function asUser(id){await db.exec(`reset role;set role ${id?'authenticated':'anon'};select set_config('test.uid','${id??''}',false);`);}
const migration=name=>db.exec('reset role;'+readFileSync(new URL(`../supabase/migrations/${name}`,import.meta.url),'utf8'));
try {
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 grant usage on schema auth,public to anon,authenticated,service_role;
 create table profiles(id uuid primary key,role text not null default 'buyer',display_name text,email text,phone text,
  avatar_url text,shipping_addresses jsonb default '[]',vendor_approved_seen_at timestamptz,tradesafe_token_id text,
  admin_role text default 'none',user_role text default 'consumer',is_verified_host boolean default false,
  onboarding_status text default 'draft',onboarding_last_note text,onboarding_reviewed_at timestamptz,
  created_at timestamptz default now(),updated_at timestamptz default now());
 create table shops(id uuid primary key,vendor_id uuid,name text);
 create table orders(id uuid primary key,buyer_id uuid,shop_id uuid);
 alter table profiles enable row level security;
 grant all on profiles,shops,orders to anon,authenticated,service_role;
 create policy "Profiles are viewable by everyone" on profiles for select using(true);
 create policy "Users can insert own profile" on profiles for insert with check(auth.uid()=id);
 create policy "Users can update own profile" on profiles for update using(auth.uid()=id);
 create function public.current_user_is_admin() returns boolean language sql stable as
  $$select exists(select 1 from public.profiles where profiles.id=auth.uid() and profiles.role='admin')$$;
 create table posts(id int primary key,is_published boolean);
 alter table posts enable row level security;
 grant select on posts to anon,authenticated;
 create policy posts_read on posts for select using(is_published or (select current_user_is_admin()));
 insert into posts values(1,true);
 insert into profiles(id,role,display_name,email,phone,shipping_addresses) values
  ('${buyer}','buyer','Buyer','buyer@example.com','0821','[{"city":"Durban"}]'),
  ('${maker}','vendor','Maker','maker@example.com','0822','[]'),
  ('${stranger}','buyer','Stranger','s@example.com','0823','[]');
 insert into shops values('${shop}','${maker}','Studio');
 insert into orders values('${order}','${buyer}','${shop}');`);
 await migration('20260925092917_harden_profile_writes.sql');
 await asUser(null);
 ok('baseline: guests can read every email',(await rows(`select email from profiles`)).length===3);

 await migration('20260927220000_add_private_profile_readers.sql');
 await asUser(buyer);
 const mine=await rows(`select * from get_my_profile()`);
 ok('get_my_profile returns only own full row',mine.length===1&&mine[0].email==='buyer@example.com'&&mine[0].shipping_addresses[0].city==='Durban');
 await asUser(maker);
 ok('vendor gets buyer contact for own shop order',(await rows(`select * from get_order_buyer_contacts(array['${order}']::uuid[])`))[0]?.email==='buyer@example.com');
 await asUser(stranger);
 ok('stranger gets no buyer contact',(await rows(`select * from get_order_buyer_contacts(array['${order}']::uuid[])`)).length===0);
 await asUser(null);
 await denied('guests cannot call get_my_profile',`select * from get_my_profile()`);
 await denied('guests cannot call buyer contacts',`select * from get_order_buyer_contacts(array['${order}']::uuid[])`);

 await db.exec('reset role');
 await migration('20260927223000_hide_private_profile_fields_from_guests.sql');
 await migration('20260927231000_allow_guest_profile_role_for_policies.sql');
 await asUser(null);
 ok('guests still read public display fields',(await rows(`select id,display_name,avatar_url from profiles`)).length===3);
 await denied('guests cannot read email',`select email from profiles`);
 await denied('guests cannot read phone',`select phone from profiles`);
 await denied('guests cannot select *',`select * from profiles`);
 ok('guest reads through admin-checking policies (regression)',(await rows(`select * from posts`)).length===1);
 await denied('guests cannot probe emails by filter',`select id from profiles where email ilike '%example%'`);
 await asUser(buyer);
 ok('stage 1 leaves member reads intact',(await rows(`select * from profiles where id='${buyer}'`))[0].email==='buyer@example.com');

 await db.exec('reset role');
 await migration('20260927224000_hide_private_profile_fields_from_members.sql');
 await asUser(stranger);
 ok('member reads through admin-checking policies after stage 2',(await rows(`select * from posts`)).length===1);
 ok('members read public fields of others',(await rows(`select id,display_name,avatar_url,role from profiles where id='${buyer}'`))[0].display_name==='Buyer');
 await denied('members cannot read others email',`select email from profiles where id='${buyer}'`);
 await denied('members cannot read shipping addresses',`select shipping_addresses from profiles`);
 await denied('members cannot select *',`select * from profiles`);
 await asUser(buyer);
 ok('own private fields via get_my_profile',(await rows(`select phone from get_my_profile()`))[0].phone==='0821');
 await works('owner updates contact fields',`update profiles set phone='0999',shipping_addresses='[]' where id='${buyer}'`);
 ok('update landed',(await rows(`select phone from get_my_profile()`))[0].phone==='0999');
 await works('insert-only sign-in upsert still works',`insert into profiles(id,role,display_name,email) values('${buyer}','buyer','Buyer B','buyer@example.com') on conflict(id) do nothing`);
 await works('merge upsert of public fields still works',`insert into profiles(id,role,display_name) values('${buyer}','buyer','Buyer B') on conflict(id) do update set role=excluded.role,display_name=excluded.display_name`);
 await denied('merge upsert of private fields needs a new client',`insert into profiles(id,email) values('${buyer}','b@example.com') on conflict(id) do update set email=excluded.email`);
 await denied('owner still cannot promote self',`update profiles set role='admin' where id='${buyer}'`);
 await asUser(fresh);
 await works('new signup profile insert works',`insert into profiles(id,role,display_name,email) values('${fresh}','buyer','New','new@example.com')`);
 await denied('new signup cannot self-approve',`insert into profiles(id,role) values('${fresh}','vendor') on conflict(id) do update set role=excluded.role`);
 await asUser(maker);
 await works('app sign-in sync update works for existing vendor',`update profiles set role='vendor',display_name='Maker',email='maker@example.com',phone='0822',avatar_url=null where id='${maker}'`);
 await works('approved vendor re-sign-in upsert keeps role',`insert into profiles(id,role,display_name) values('${maker}','vendor','Maker') on conflict(id) do update set role=excluded.role,display_name=excluded.display_name`);
 ok('vendor contact RPC still works after stage 2',(await rows(`select phone from get_order_buyer_contacts(array['${order}']::uuid[])`))[0]?.phone==='0999');
 await db.exec('reset role;set role service_role');
 ok('server keeps full access',(await rows(`select email from profiles`)).length===4);
 console.log(`${passed} profile privacy assertions passed`);
} finally {await db.close();}
