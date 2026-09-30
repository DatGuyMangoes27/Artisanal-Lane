import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
// Mirrors the live post/story/report policies, then applies the creator parity
// migration and checks visibility, ownership and privacy of every new feature.
const db = new PGlite();
const maker = '10000000-0000-0000-0000-000000000001', fan = '10000000-0000-0000-0000-000000000002',
  other = '10000000-0000-0000-0000-000000000003', otherMaker = '10000000-0000-0000-0000-000000000004',
  shop = '20000000-0000-0000-0000-000000000001', shop2 = '20000000-0000-0000-0000-000000000002',
  closedShop = '20000000-0000-0000-0000-000000000003',
  post = '30000000-0000-0000-0000-000000000001', post2 = '30000000-0000-0000-0000-000000000002',
  product = '40000000-0000-0000-0000-000000000001', story = '50000000-0000-0000-0000-000000000001',
  oldStory = '50000000-0000-0000-0000-000000000002';
let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); passed++; };
async function denied(label, sql) { let err; try { await db.exec(sql); } catch (e) { err = e; } ok(label, !!err); }
const rows = async sql => (await db.query(sql)).rows;
async function as(id) { await db.exec(`reset role;set role ${id ? 'authenticated' : 'anon'};select set_config('test.uid','${id ?? ''}',false);`); }
const migration = name => db.exec('reset role;' + readFileSync(new URL(`../supabase/migrations/${name}`, import.meta.url), 'utf8'));
try {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  grant usage on schema auth,public to anon,authenticated,service_role;
  create table profiles(id uuid primary key,role text default 'buyer',display_name text);
  create function public.current_user_is_admin() returns boolean language sql stable as
   $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;
  create table shops(id uuid primary key,vendor_id uuid,name text,bio text,is_active boolean default true,is_offline boolean default false,
   is_spotlight boolean default false,spotlighted_at timestamptz,created_at timestamptz default now());
  create function public.guard_shop_privileged_fields() returns trigger language plpgsql as $$begin return new; end$$;
  create trigger guard_shop_privileged_fields before update on shops for each row execute function public.guard_shop_privileged_fields();
  create table products(id uuid primary key,shop_id uuid,is_published boolean default true);
  create table shop_posts(id uuid primary key,shop_id uuid references shops(id),caption text not null default '',media_urls jsonb default '[]',
   is_published boolean default true,created_at timestamptz default now(),updated_at timestamptz default now(),product_ids uuid[] default '{}');
  create table shop_post_likes(post_id uuid,user_id uuid,created_at timestamptz default now(),primary key(post_id,user_id));
  create table shop_post_comments(id uuid primary key default gen_random_uuid(),post_id uuid,user_id uuid,body text,created_at timestamptz default now());
  create table shop_stories(id uuid primary key,shop_id uuid,caption text,expires_at timestamptz);
  create table shop_follows(id uuid primary key default gen_random_uuid(),user_id uuid,shop_id uuid,created_at timestamptz default now());
  do $$declare t text;begin foreach t in array array['profiles','shops','products','shop_posts','shop_post_likes','shop_post_comments','shop_stories','shop_follows'] loop
   execute format('alter table %I enable row level security',t); execute format('grant all on %I to anon,authenticated,service_role',t); end loop;end$$;
  create policy p_read on profiles for select using(true);
  create policy s_read on shops for select using(true);
  create policy s_upd on shops for update using(vendor_id=auth.uid());
  create policy pr_read on products for select using(true);
  create policy "Published posts are publicly readable" on shop_posts for select using(is_published=true);
  create policy shop_posts_owner_select on shop_posts for select to authenticated using((select current_user_is_admin()) or exists(select 1 from shops s where s.id=shop_posts.shop_id and s.vendor_id=(select auth.uid())));
  create policy creator_posts_read_guard on shop_posts as restrictive for select to anon,authenticated using((select current_user_is_admin())
   or exists(select 1 from shops s where s.id=shop_posts.shop_id and (s.vendor_id=(select auth.uid()) or (shop_posts.is_published and s.is_active and not s.is_offline))));
  create policy posts_upd on shop_posts for update using(exists(select 1 from shops s where s.id=shop_posts.shop_id and s.vendor_id=auth.uid()));
  create policy likes_read on shop_post_likes for select using(exists(select 1 from shop_posts p where p.id=post_id));
  create policy likes_ins on shop_post_likes for insert to authenticated with check(user_id=auth.uid());
  create policy post_comments_read on shop_post_comments for select using(exists(select 1 from shop_posts p where p.id=post_id));
  create policy post_comments_insert on shop_post_comments for insert to authenticated with check((user_id=(select auth.uid())) and exists(select 1 from shop_posts p where p.id=shop_post_comments.post_id and p.is_published));
  create policy st_read on shop_stories for select using(expires_at>now());
  create policy f_read on shop_follows for select using(true);
  create function public.get_post_engagement(post_ids uuid[]) returns table(post_id uuid, like_count bigint, comment_count bigint, liked_by_me boolean)
   language sql stable as $$select null::uuid,null::bigint,null::bigint,false where false$$;
  insert into profiles(id,display_name) values('${maker}','Maker'),('${fan}','Fan'),('${other}','Other'),('${otherMaker}','Other maker');
  insert into shops(id,vendor_id,name,bio) values('${shop}','${maker}','Clay Studio','Hand-thrown bowls'),('${shop2}','${otherMaker}','Loom','Weaving');
  insert into shops(id,vendor_id,name,is_active) values('${closedShop}','${otherMaker}','Closed',false);
  insert into products values('${product}','${shop}',true);
  insert into shop_posts(id,shop_id,caption) values('${post}','${shop}','New glaze'),('${post2}','${shop2}','Loom day');
  insert into shop_post_likes(post_id,user_id) values('${post}','${fan}'),('${post}','${other}');
  insert into shop_stories values('${story}','${shop}','Kiln',now()+interval '1 day'),('${oldStory}','${shop}','Old',now()-interval '1 hour');`);
  await migration('20260925092400_creator_content_reports.sql');
  await migration('20260928090000_creator_parity_features.sql');
  await migration('20260929100000_report_reviewer_from_server.sql');
  // Supabase grants the service role on new tables by default.
  await db.exec('grant all on creator_content_reports to service_role');

  await as(fan);
  const p = (await rows(`select comments_enabled,hide_like_count,format,published_at=created_at same from shop_posts where id='${post}'`))[0];
  ok('existing posts keep today\'s behaviour', p.comments_enabled && !p.hide_like_count && p.format === 'photo' && p.same);

  // Scheduling
  await as(maker);
  await db.exec(`update shop_posts set scheduled_for=now()+interval '2 days' where id='${post}'`);
  ok('maker still sees their scheduled post', (await rows(`select id from shop_posts where id='${post}'`)).length === 1);
  await as(fan);
  ok('fans cannot see a scheduled post early', (await rows(`select id from shop_posts where id='${post}'`)).length === 0);
  await as(null);
  ok('guests cannot see a scheduled post early', (await rows(`select id from shop_posts where id='${post}'`)).length === 0);
  await as(fan);
  await denied('no comments on a scheduled post', `insert into shop_post_comments(post_id,user_id,body) values('${post}','${fan}','hi')`);
  await as(maker);
  await db.exec(`update shop_posts set scheduled_for=now()-interval '1 minute' where id='${post}'`);
  await as(fan);
  ok('post appears once its time arrives', (await rows(`select id from shop_posts where id='${post}'`)).length === 1);
  ok('published_at follows the schedule', (await rows(`select published_at=scheduled_for s from shop_posts where id='${post}'`))[0].s);

  // Comments setting
  await db.exec(`insert into shop_post_comments(post_id,user_id,body) values('${post}','${fan}','Lovely')`);
  ok('comments work when enabled', (await rows(`select id from shop_post_comments where post_id='${post}'`)).length === 1);
  await as(maker);
  await db.exec(`update shop_posts set comments_enabled=false where id='${post}'`);
  await as(fan);
  await denied('comments blocked when the maker turns them off', `insert into shop_post_comments(post_id,user_id,body) values('${post}','${fan}','Again')`);

  // Hidden like counts
  await as(maker);
  await db.exec(`update shop_posts set hide_like_count=true where id='${post}'`);
  ok('maker still sees their like count', (await rows(`select like_count from get_post_engagement(array['${post}']::uuid[])`))[0].like_count == 2);
  await as(fan);
  const eng = (await rows(`select like_count,comment_count,liked_by_me from get_post_engagement(array['${post}']::uuid[])`))[0];
  ok('others see no like count when hidden', eng.like_count === null && eng.liked_by_me === true && eng.comment_count == 1);

  // Polls
  await as(fan);
  await denied('only the maker can add a poll', `insert into post_polls values('${post}','Which glaze?','["Blue","Green"]',null)`);
  await as(maker);
  await db.exec(`insert into post_polls values('${post}','Which glaze next?','["Blue","Green","Rust"]',null)`);
  await denied('a poll needs at least two options', `update post_polls set options='["Only"]' where post_id='${post}'`);
  await as(null);
  ok('guests can read a visible poll', (await rows(`select question from post_polls`)).length === 1);
  await as(fan);
  await db.exec(`insert into post_poll_votes(post_id,option_index) values('${post}',1)`);
  await denied('one vote per person', `insert into post_poll_votes(post_id,option_index) values('${post}',0)`);
  await denied('cannot vote for an option that does not exist', `update post_poll_votes set option_index=3 where post_id='${post}'`);
  await db.exec(`update post_poll_votes set option_index=2 where post_id='${post}'`);
  await as(other);
  await db.exec(`insert into post_poll_votes(post_id,option_index) values('${post}',2)`);
  ok('votes are private to the voter', (await rows(`select * from post_poll_votes`)).length === 1);
  const res = await rows(`select * from get_poll_results('${post}') order by option_index`);
  ok('results show counts and my vote only', res.length === 3 && res[2].votes == 2 && res[0].votes == 0 && res[2].my_vote === 2);
  await as(null);
  ok('guests see results without a vote of their own', (await rows(`select * from get_poll_results('${post}')`)).every(r => r.my_vote === null));
  await as(maker);
  await db.exec(`update post_polls set closes_at=now()-interval '1 minute' where post_id='${post}'`);
  await as(fan);
  await denied('closed polls take no new votes', `delete from post_poll_votes where post_id='${post}'; insert into post_poll_votes(post_id,option_index) values('${post}',0)`);
  await as(maker);
  await db.exec(`update shop_posts set scheduled_for=now()+interval '1 day' where id='${post}'`);
  await as(null);
  ok('scheduled poll results stay hidden from guests', (await rows(`select * from get_poll_results('${post}')`)).length === 0);
  await as(maker);
  await db.exec(`update shop_posts set scheduled_for=null where id='${post}'`);

  // Saved posts and muted makers
  await as(fan);
  await db.exec(`insert into saved_posts(post_id) values('${post}'); insert into muted_shops(shop_id) values('${shop2}')`);
  await denied('cannot save a post for someone else', `insert into saved_posts(user_id,post_id) values('${other}','${post2}')`);
  await as(other);
  ok('saved posts are private', (await rows(`select * from saved_posts`)).length === 0);
  ok('muted makers are private', (await rows(`select * from muted_shops`)).length === 0);
  await as(fan);
  ok('owner sees their saves and mutes', (await rows(`select * from saved_posts`)).length === 1 && (await rows(`select * from muted_shops`)).length === 1);

  // Verified makers
  await as(maker);
  await denied('makers cannot verify themselves', `update shops set is_verified=true where id='${shop}'`);
  await db.exec(`reset role;set role service_role;update shops set is_verified=true where id='${shop}'`);
  ok('admins verify through the server', (await rows(`select is_verified from shops where id='${shop}'`))[0].is_verified === true);

  // Insights and view tracking
  await as(null);
  await db.exec(`select record_content_view('post','${post}','sess-1'); select record_content_view('post','${post}','sess-1'); select record_content_view('product','${product}','sess-1')`);
  await db.exec(`select record_content_view('post','${post}',null)`);
  await as(fan);
  await db.exec(`select record_content_view('post','${post}'); select record_content_view('shop','${shop}'); select record_content_view('shop','${closedShop}')`);
  await as(maker);
  await db.exec(`select record_content_view('post','${post}')`);
  await denied('raw views are not readable', `select * from content_views`);
  const ins = (await rows(`select get_shop_insights(30) i`))[0].i;
  ok('insights count unique viewers per day, not the maker', ins.post_views == 2 && ins.product_views == 1 && ins.profile_views == 1);
  ok('insights include likes, comments, saves and followers', ins.likes == 2 && ins.comments == 1 && ins.saves == 1 && ins.followers == 0);
  ok('top posts listed', ins.top_posts.length === 1 && ins.top_posts[0].views == 2);
  await as(fan);
  ok('non-makers get no insights', (await rows(`select get_shop_insights(30) i`))[0].i === null);
  await as(null);
  await denied('guests cannot read insights', `select get_shop_insights(30)`);

  // Maker reports
  await as(fan);
  await db.exec(`insert into creator_content_reports(target_type,target_id,reason,details) values('shop','${shop2}','spam','Copies my work')`);
  const rep = (await rows(`select target_text_snapshot,target_owner_id from creator_content_reports where target_type='shop'`))[0];
  ok('maker reports snapshot the shop', rep.target_text_snapshot.startsWith('Loom') && rep.target_owner_id === otherMaker);
  await denied('closed shops cannot be reported', `insert into creator_content_reports(target_type,target_id,reason) values('shop','${closedShop}','spam')`);
  await db.exec(`insert into creator_content_reports(target_type,target_id,reason) values('post','${post}','other')`);
  await db.exec(`reset role;set role service_role;update creator_content_reports set status='resolved',reviewed_by='${otherMaker}' where target_type='shop'`);
  ok('server-side review keeps the admin it names', (await rows(`select reviewed_by from creator_content_reports where target_type='shop'`))[0].reviewed_by === otherMaker);
  await as(fan);
  ok('post reports still work', (await rows(`select id from creator_content_reports where target_type='post'`)).length === 1);

  // Story reactions
  await as(fan);
  await db.exec(`insert into story_reactions(story_id,emoji) values('${story}','🔥')`);
  await denied('only the set emojis', `update story_reactions set emoji='💩' where story_id='${story}'`);
  await denied('no reactions to expired stories', `insert into story_reactions(story_id,emoji) values('${oldStory}','❤️')`);
  await as(other);
  ok('other viewers cannot see reactions', (await rows(`select * from story_reactions`)).length === 0);
  await as(maker);
  ok('the maker sees reactions to their story', (await rows(`select emoji from story_reactions`))[0]?.emoji === '🔥');
  await as(otherMaker);
  ok('other makers cannot see them', (await rows(`select * from story_reactions`)).length === 0);

  console.log(`${passed} creator parity assertions passed`);
} finally { await db.close(); }
