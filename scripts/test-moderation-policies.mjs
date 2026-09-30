import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
// Mirrors the live post/comment/chat policies, applies the moderation
// migration, and checks blocking, takedowns and the admin log.
const db = new PGlite();
const maker = '10000000-0000-0000-0000-000000000001', buyer = '10000000-0000-0000-0000-000000000002',
  other = '10000000-0000-0000-0000-000000000003', admin = '10000000-0000-0000-0000-000000000004',
  shop = '20000000-0000-0000-0000-000000000001', post = '30000000-0000-0000-0000-000000000001',
  thread = '40000000-0000-0000-0000-000000000001';
let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); passed++; };
async function denied(label, sql) { let err; try { await db.exec(sql); } catch (e) { err = e; } ok(label, !!err); }
const rows = async sql => (await db.query(sql)).rows;
async function as(id) { await db.exec(`reset role;set role ${id ? 'authenticated' : 'anon'};select set_config('test.uid','${id ?? ''}',false);`); }
try {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  grant usage on schema auth,public to anon,authenticated,service_role;
  create table profiles(id uuid primary key,role text default 'buyer');
  create function public.current_user_is_admin() returns boolean language sql stable as
   $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;
  create table shops(id uuid primary key,vendor_id uuid);
  create table shop_posts(id uuid primary key,shop_id uuid,is_published boolean default true,caption text default '');
  create table shop_post_likes(post_id uuid,user_id uuid,primary key(post_id,user_id));
  create table shop_post_comments(id uuid primary key default gen_random_uuid(),post_id uuid,user_id uuid,body text);
  create table chat_threads(id uuid primary key default gen_random_uuid(),shop_id uuid,buyer_id uuid,vendor_id uuid,kind text default 'buyer_vendor');
  create table chat_messages(id uuid primary key default gen_random_uuid(),thread_id uuid,sender_id uuid,body text);
  create table creator_content_reports(id uuid primary key default gen_random_uuid());
  do $$declare t text;begin foreach t in array array['profiles','shops','shop_posts','shop_post_likes','shop_post_comments','chat_threads','chat_messages','creator_content_reports'] loop
   execute format('alter table %I enable row level security',t); execute format('grant all on %I to anon,authenticated,service_role',t); end loop;end$$;
  create policy p_read on profiles for select using(true);
  create policy s_read on shops for select using(true);
  create policy posts_read on shop_posts for select using(is_published);
  create policy posts_owner on shop_posts for select to authenticated using(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()));
  create policy posts_upd on shop_posts for update using(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()));
  create policy likes_ins on shop_post_likes for insert to authenticated with check(user_id=auth.uid());
  create policy comments_ins on shop_post_comments for insert to authenticated with check(user_id=auth.uid());
  create policy comments_read on shop_post_comments for select using(true);
  create policy threads_ins on chat_threads for insert to authenticated with check(buyer_id=auth.uid() or vendor_id=auth.uid());
  create policy threads_read on chat_threads for select using(buyer_id=auth.uid() or vendor_id=auth.uid());
  create policy msgs_ins on chat_messages for insert to authenticated with check(sender_id=auth.uid());
  insert into profiles values('${maker}','vendor'),('${buyer}','buyer'),('${other}','buyer'),('${admin}','admin');
  insert into shops values('${shop}','${maker}');
  insert into shop_posts(id,shop_id) values('${post}','${shop}');
  insert into chat_threads(id,shop_id,buyer_id,vendor_id) values('${thread}','${shop}','${buyer}','${maker}');`);
  await db.exec('reset role;' + readFileSync(new URL('../supabase/migrations/20260929090000_creator_moderation.sql', import.meta.url), 'utf8'));
  // Supabase grants the service role on new tables by default.
  await db.exec('grant all on moderation_actions, user_blocks to service_role');

  // Blocking
  await as(buyer);
  await db.exec(`insert into shop_post_comments(post_id,user_id,body) values('${post}','${buyer}','Lovely')`);
  await db.exec(`insert into chat_messages(thread_id,sender_id,body) values('${thread}','${buyer}','Hi')`);
  ok('unblocked people can comment and message', (await rows(`select 1 from shop_post_comments`)).length === 1);
  await denied('cannot block yourself', `insert into user_blocks(blocked_id) values('${buyer}')`);
  await denied('cannot block on someone else\'s behalf', `insert into user_blocks(blocker_id,blocked_id) values('${other}','${maker}')`);
  await as(maker);
  await db.exec(`insert into user_blocks(blocked_id) values('${buyer}')`);
  await as(buyer);
  await denied('blocked buyer cannot comment on the maker\'s posts', `insert into shop_post_comments(post_id,user_id,body) values('${post}','${buyer}','Again')`);
  await denied('blocked buyer cannot message the maker', `insert into chat_messages(thread_id,sender_id,body) values('${thread}','${buyer}','Hello?')`);
  await denied('blocked buyer cannot open a new chat with the shop', `insert into chat_threads(shop_id,buyer_id,vendor_id) values('${shop}','${buyer}','${maker}')`);
  ok('blocks are private to the blocker', (await rows(`select * from user_blocks`)).length === 0);
  await as(maker);
  await denied('the maker cannot message the person they blocked either', `insert into chat_messages(thread_id,sender_id,body) values('${thread}','${maker}','x')`);
  ok('the blocker sees their block list', (await rows(`select * from user_blocks`)).length === 1);
  await as(other);
  await db.exec(`insert into shop_post_comments(post_id,user_id,body) values('${post}','${other}','Nice')`);
  ok('other people are unaffected', (await rows(`select 1 from shop_post_comments where user_id='${other}'`)).length === 1);
  await as(maker);
  await db.exec(`delete from user_blocks where blocked_id='${buyer}'`);
  await as(buyer);
  await db.exec(`insert into shop_post_comments(post_id,user_id,body) values('${post}','${buyer}','Back')`);
  ok('unblocking restores commenting', (await rows(`select 1 from shop_post_comments where body='Back'`)).length === 1);

  // Takedowns
  await as(maker);
  await denied('makers cannot remove posts via the moderation fields', `update shop_posts set removed_at=now() where id='${post}'`);
  await db.exec(`reset role;set role service_role;update shop_posts set removed_at=now(),removed_reason='Copyright' where id='${post}'`);
  await as(buyer);
  ok('removed posts disappear for buyers', (await rows(`select * from shop_posts`)).length === 0);
  await as(null);
  ok('removed posts disappear for guests', (await rows(`select * from shop_posts`)).length === 0);
  await as(maker);
  ok('the maker still sees their removed post and the reason', (await rows(`select removed_reason from shop_posts`))[0]?.removed_reason === 'Copyright');
  await denied('the maker cannot restore it', `update shop_posts set removed_at=null where id='${post}'`);
  await denied('the maker cannot create a pre-removed post', `insert into shop_posts(id,shop_id,removed_at) values(gen_random_uuid(),'${shop}',now())`);
  await as(admin);
  ok('admins still see removed posts', (await rows(`select * from shop_posts`)).length === 1);
  await as(other);
  await denied('no likes on removed posts', `insert into shop_post_likes(post_id,user_id) values('${post}','${other}')`);
  await denied('no comments on removed posts', `insert into shop_post_comments(post_id,user_id,body) values('${post}','${other}','x')`);
  await db.exec(`reset role;set role service_role;update shop_posts set removed_at=null,removed_reason=null where id='${post}'`);
  await as(buyer);
  ok('restored posts come back', (await rows(`select * from shop_posts`)).length === 1);

  // Admin log
  await db.exec(`reset role;set role service_role;insert into moderation_actions(admin_id,action,target_type,target_id,note) values('${admin}','remove_post','post','${post}','Copyright')`);
  await as(maker);
  ok('makers cannot read the moderation log', (await rows(`select * from moderation_actions`)).length === 0);
  await denied('members cannot write to the log', `insert into moderation_actions(action,target_type,target_id) values('remove_post','post','${post}')`);
  await as(admin);
  ok('admins can read the moderation log', (await rows(`select * from moderation_actions`)).length === 1);

  console.log(`${passed} moderation assertions passed`);
} finally { await db.close(); }
