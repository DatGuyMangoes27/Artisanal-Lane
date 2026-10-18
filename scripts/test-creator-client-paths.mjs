import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
// Runs the exact SQL the app's PostgREST calls produce (feed query, poll
// attach, vote upsert, close-early upsert) against the deployed creator
// migrations. Proves scheduled posts go live on time with no background job,
// and that the poll flow works end to end. Same base schema as
// test-creator-parity-policies.mjs, plus the chat tables moderation fences.
const db = new PGlite();
const maker = '10000000-0000-0000-0000-000000000001', fan = '10000000-0000-0000-0000-000000000002',
  other = '10000000-0000-0000-0000-000000000003', otherMaker = '10000000-0000-0000-0000-000000000004',
  shop = '20000000-0000-0000-0000-000000000001', shop2 = '20000000-0000-0000-0000-000000000002',
  closedShop = '20000000-0000-0000-0000-000000000003',
  post = '30000000-0000-0000-0000-000000000001', post2 = '30000000-0000-0000-0000-000000000002',
  product = '40000000-0000-0000-0000-000000000001', story = '50000000-0000-0000-0000-000000000001',
  oldStory = '50000000-0000-0000-0000-000000000002',
  later = '30000000-0000-0000-0000-000000000003', laterPoll = '30000000-0000-0000-0000-000000000004';
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
  create table chat_threads(id uuid primary key default gen_random_uuid(),kind text,shop_id uuid,buyer_id uuid,vendor_id uuid);
  create table chat_messages(id uuid primary key default gen_random_uuid(),thread_id uuid);
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
  create policy posts_ins on shop_posts for insert to authenticated with check(exists(select 1 from shops s where s.id=shop_posts.shop_id and s.vendor_id=auth.uid()));
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
  await migration('20260929090000_creator_moderation.sql');

  // The exact statements PostgREST runs for the app's calls.
  const feed = async () => (await rows(
    `select id from shop_posts where is_published order by published_at desc, id desc`)).map(r => r.id);
  const vote = (option) => `insert into post_poll_votes(post_id,option_index) values('${post}',${option})
    on conflict (post_id,user_id) do update set post_id=excluded.post_id, option_index=excluded.option_index`;

  // ── Scheduling needs no job: visibility is decided by the clock ─────────
  await as(maker);
  await db.exec(`insert into shop_posts(id,shop_id,caption,scheduled_for,format) values
    ('${later}','${shop}','Kiln opening',now()+interval '1 hour','photo')`);
  ok('the maker sees the scheduled post first in their own feed', (await feed())[0] === later);
  await as(fan);
  ok('fans do not get the scheduled post in the feed', !(await feed()).includes(later));
  await as(null);
  ok('guests do not get the scheduled post in the feed', !(await feed()).includes(later));
  await as(fan);
  ok('scheduled posts take no likes', await (async () => {
    try { await db.exec(`insert into shop_post_likes(post_id,user_id) values('${later}','${fan}')`); } catch { return true; }
    return (await rows(`select 1 from shop_post_likes where post_id='${later}'`)).length === 0;
  })());
  // Time passes: simulated by setting the schedule to the current moment,
  // which is what now() reaching scheduled_for looks like to every policy.
  await db.exec(`reset role;update shop_posts set scheduled_for=now() where id='${later}'`);
  await as(fan);
  const live = await feed();
  ok('once due it appears for fans with no job or edit', live.includes(later));
  ok('and it is ordered by its go-live time, ahead of older posts', live[0] === later);
  await as(null);
  ok('and for guests', (await feed()).includes(later));

  // ── Poll: create, attach idempotently, vote, change vote, close ─────────
  await as(maker);
  await db.exec(`update shop_posts set format='poll' where id='${post}'`);
  const attach = `insert into post_polls(post_id,question,options,closes_at) values
    ('${post}','Which glaze next?','["Blue","Green","Rust"]',null) on conflict (post_id) do nothing`;
  await db.exec(attach);
  await db.exec(attach);
  ok('retrying the poll attach keeps one poll', (await rows(`select 1 from post_polls where post_id='${post}'`)).length === 1);
  await as(fan);
  await db.exec(vote(0));
  await db.exec(vote(2));
  let res = await rows(`select * from get_poll_results('${post}') order by option_index`);
  ok('an upserted vote change moves the single vote', res[0].votes == 0 && res[2].votes == 1 && res[2].my_vote === 2);
  await as(other);
  await db.exec(vote(2));
  res = await rows(`select * from get_poll_results('${post}') order by option_index`);
  ok('every voter counts once in the live results', res[2].votes == 2 && res[2].my_vote === 2);
  await denied('an out-of-range option is refused through the upsert', vote(3));
  await as(maker);
  ok('the maker reads live results for their poll', (await rows(`select sum(votes)::int n from get_poll_results('${post}')`))[0].n === 2);
  await db.exec(`insert into post_polls(post_id,question,options,closes_at) values
    ('${post}','Which glaze next?','["Blue","Green","Rust"]',now()) on conflict (post_id) do update set
    question=excluded.question, options=excluded.options, closes_at=excluded.closes_at`);
  await as(fan);
  await denied('a vote change after the maker closes the poll is refused', vote(1));
  res = await rows(`select * from get_poll_results('${post}') order by option_index`);
  ok('closed results stay readable with the final count', res[2].votes == 2 && res[2].my_vote === 2);
  await as(other);
  try { await db.exec(`update post_polls set closes_at=null where post_id='${post}'`); } catch { /* refused outright */ }
  ok('the poll stays closed', (await rows(`select closes_at is not null c from post_polls where post_id='${post}'`))[0].c);

  // A poll on a scheduled post can't be voted on early.
  await as(maker);
  await db.exec(`insert into shop_posts(id,shop_id,caption,scheduled_for,format) values
    ('${laterPoll}','${shop}','Vote soon',now()+interval '1 day','poll');
    insert into post_polls(post_id,question,options) values('${laterPoll}','Colour?','["Red","Blue"]')`);
  await as(fan);
  await denied('no votes on a poll before its post goes live',
    `insert into post_poll_votes(post_id,option_index) values('${laterPoll}',0)`);

  // ── Removed posts drop out of feeds and stop taking votes ──────────────
  await db.exec(`reset role;update shop_posts set removed_at=now(),removed_reason='Spam' where id='${post2}'`);
  await as(fan);
  ok('a removed post leaves the public feed', !(await feed()).includes(post2));
  await as(otherMaker);
  ok('its maker still sees it (with the removal banner)', (await feed()).includes(post2));

  console.log(`${passed} creator client-path assertions passed`);
} finally { await db.close(); }
