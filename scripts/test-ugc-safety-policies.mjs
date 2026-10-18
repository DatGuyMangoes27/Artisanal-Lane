// Isolated PostgreSQL tests for 20261018100000_ugc_safety.sql; never connects
// to the live project. Mirrors the live UGC tables, applies the real report,
// moderation and profile-hardening migrations, then the UGC safety migration.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const buyer = '10000000-0000-0000-0000-000000000001', maker = '10000000-0000-0000-0000-000000000002',
  outsider = '10000000-0000-0000-0000-000000000003', admin = '10000000-0000-0000-0000-000000000004',
  shop = '20000000-0000-0000-0000-000000000001', post = '30000000-0000-0000-0000-000000000001',
  legacyComment = '31000000-0000-0000-0000-000000000001', product = '40000000-0000-0000-0000-000000000001',
  productReview = '41000000-0000-0000-0000-000000000001', shopReview = '42000000-0000-0000-0000-000000000001',
  thread = '50000000-0000-0000-0000-000000000001', message = '51000000-0000-0000-0000-000000000001';
const BLOCKED = "This text contains language that isn't allowed on Artisan Lane.";
let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); passed++; };
async function failure(sql) { try { await db.exec(sql); } catch (e) { return e; } return null; }
async function denied(label, sql) { ok(label, !!(await failure(sql))); }
async function blocked(label, sql) { const e = await failure(sql); ok(label, e && String(e.message).includes(BLOCKED)); }
const rows = async sql => (await db.query(sql)).rows;
const migration = name => readFileSync(new URL(`../supabase/migrations/${name}`, import.meta.url), 'utf8');
async function as(id) { await db.exec(`reset role;set role ${id ? 'authenticated' : 'anon'};select set_config('test.uid','${id ?? ''}',false);`); }

try {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  grant usage on schema auth,public to anon,authenticated,service_role;
  create table profiles(id uuid primary key,role text not null default 'buyer',display_name text,email text,
    phone text,avatar_url text,shipping_addresses jsonb default '[]',vendor_approved_seen_at timestamptz,
    created_at timestamptz default now(),updated_at timestamptz default now());
  create function public.current_user_is_admin() returns boolean language sql stable as
    $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;
  create table shops(id uuid primary key,vendor_id uuid,name text not null,bio text,brand_story text,is_active boolean default true);
  create table shop_posts(id uuid primary key,shop_id uuid,caption text not null default '',is_published boolean default true,
    step_captions jsonb not null default '[]');
  create table shop_post_likes(post_id uuid,user_id uuid,primary key(post_id,user_id));
  create table shop_post_comments(id uuid primary key default gen_random_uuid(),post_id uuid,user_id uuid,body text not null,edited boolean default false);
  create table shop_stories(id uuid primary key default gen_random_uuid(),shop_id uuid,caption text not null default '',
    expires_at timestamptz not null default now()+interval '24 hours');
  create table post_polls(post_id uuid primary key,question text not null,options jsonb not null);
  create table product_reviews(id uuid primary key default gen_random_uuid(),product_id uuid,shop_id uuid,buyer_id uuid,
    rating int not null,review_text text);
  create table shop_reviews(id uuid primary key default gen_random_uuid(),shop_id uuid,buyer_id uuid,rating int not null,review_text text);
  create table chat_threads(id uuid primary key default gen_random_uuid(),shop_id uuid,buyer_id uuid,vendor_id uuid,kind text default 'buyer_vendor');
  create table chat_messages(id uuid primary key default gen_random_uuid(),thread_id uuid,sender_id uuid,body text,attachment_name text);
  create table products(id uuid primary key default gen_random_uuid(),shop_id uuid,title text not null,description text,price numeric default 0);
  do $$declare t text;begin foreach t in array array['profiles','shops','shop_posts','shop_post_likes','shop_post_comments',
    'shop_stories','post_polls','product_reviews','shop_reviews','chat_threads','chat_messages','products'] loop
    execute format('alter table %I enable row level security',t); execute format('grant all on %I to anon,authenticated,service_role',t); end loop;end$$;
  create policy profiles_all on profiles for all using(true) with check(true);
  create policy shops_read on shops for select using(true);
  create policy shops_owner on shops for update using(vendor_id=auth.uid());
  create policy posts_read on shop_posts for select using(is_published);
  create policy posts_owner on shop_posts for all to authenticated
    using(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()))
    with check(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()));
  create policy comments_read on shop_post_comments for select using(true);
  create policy comments_ins on shop_post_comments for insert to authenticated with check(user_id=auth.uid());
  create policy comments_upd on shop_post_comments for update to authenticated using(user_id=auth.uid());
  create policy stories_read on shop_stories for select using(expires_at>now());
  create policy stories_ins on shop_stories for insert to authenticated
    with check(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()));
  create policy polls_read on post_polls for select using(true);
  create policy polls_owner on post_polls for insert to authenticated
    with check(exists(select 1 from shop_posts p join shops s on s.id=p.shop_id where p.id=post_id and s.vendor_id=auth.uid()));
  create policy product_reviews_read on product_reviews for select using(true);
  create policy product_reviews_ins on product_reviews for insert to authenticated with check(buyer_id=auth.uid());
  create policy shop_reviews_read on shop_reviews for select using(true);
  create policy shop_reviews_ins on shop_reviews for insert to authenticated with check(buyer_id=auth.uid());
  create policy threads_read on chat_threads for select using(buyer_id=auth.uid() or vendor_id=auth.uid() or public.current_user_is_admin());
  create policy msgs_read on chat_messages for select using(exists(select 1 from chat_threads t where t.id=thread_id
    and (t.buyer_id=auth.uid() or t.vendor_id=auth.uid() or public.current_user_is_admin())));
  create policy msgs_ins on chat_messages for insert to authenticated with check(sender_id=auth.uid());
  create policy products_owner on products for all to authenticated
    using(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()))
    with check(exists(select 1 from shops s where s.id=shop_id and s.vendor_id=auth.uid()));
  insert into profiles(id,role,display_name) values('${buyer}','buyer','Buyer'),('${maker}','vendor','Maker'),
    ('${outsider}','buyer','Outsider'),('${admin}','admin','Admin');
  insert into shops(id,vendor_id,name,bio) values('${shop}','${maker}','Clay Studio','Hand thrown pots');
  insert into shop_posts(id,shop_id,caption) values('${post}','${shop}','New mugs');
  -- A row written before the filter existed.
  insert into shop_post_comments(id,post_id,user_id,body) values('${legacyComment}','${post}','${buyer}','what the fuck');
  insert into product_reviews(id,product_id,shop_id,buyer_id,rating,review_text)
    values('${productReview}','${product}','${shop}','${buyer}',2,'Arrived chipped');
  insert into shop_reviews(id,shop_id,buyer_id,rating,review_text) values('${shopReview}','${shop}','${buyer}',5,'Lovely maker');
  insert into chat_threads(id,shop_id,buyer_id,vendor_id) values('${thread}','${shop}','${buyer}','${maker}');
  insert into chat_messages(id,thread_id,sender_id,body) values('${message}','${thread}','${maker}','Pay me off the app');`);
  await db.exec(migration('20260925092400_creator_content_reports.sql'));
  await db.exec(migration('20260929090000_creator_moderation.sql'));
  await db.exec(migration('20260925092917_harden_profile_writes.sql'));
  await db.exec(migration('20261018100000_ugc_safety.sql'));
  await db.exec('grant all on moderation_actions, user_blocks, creator_content_reports to service_role');

  // ── Filter function ──
  const check = async text => (await rows(`select public.contains_blocked_terms(${text === null ? 'null' : `$q$${text}$q$`}) as hit`))[0].hit;
  for (const text of ['FUCK off', 'f*ck this', 'you kaffir', 'faggots', 'free porn here', 'Motherfucker', 'what a CUNT.', 'n1gger']) {
    ok(`filter blocks "${text.replace(/[aeiou1*]/gi, '#')}"`, await check(text));
  }
  for (const text of ['Scunthorpe pottery', 'cocktail glasses', 'Assassin\'s Creed mug', 'shipped from Pakistan',
    'spice rack', 'art therapist', 'flame retardant fabric', 'Hancock street', 'Dickens bookends',
    'shiitake grow kit', 'damn this is lovely', 'classic', 'Maine Coon collar', 'pussy willow wreath',
    'cum laude gift', 'Sussex trug', 'rapeseed oil soap', 'hello', '']) {
    ok(`filter allows "${text}"`, !(await check(text)));
  }
  ok('filter treats null as clean', !(await check(null)));

  // ── Triggers ──
  await as(buyer);
  await blocked('comment with a slur is rejected with the friendly message',
    `insert into shop_post_comments(post_id,user_id,body) values('${post}','${buyer}','go away faggot')`);
  await db.exec(`insert into shop_post_comments(post_id,user_id,body) values('${post}','${buyer}','Gorgeous glaze in Scunthorpe blue')`);
  ok('normal comment is accepted', (await rows(`select 1 from shop_post_comments where body like 'Gorgeous%'`)).length === 1);
  await db.exec(`update shop_post_comments set edited=true where id='${legacyComment}'`);
  ok('old rows still accept unrelated updates', (await rows(`select edited from shop_post_comments where id='${legacyComment}'`))[0].edited === true);
  await blocked('editing comment text to objectionable text is rejected',
    `update shop_post_comments set body='fuck you' where id=(select id from shop_post_comments where body like 'Gorgeous%')`);
  await blocked('chat message with a slur is rejected',
    `insert into chat_messages(thread_id,sender_id,body) values('${thread}','${buyer}','listen kaffir')`);
  await db.exec(`insert into chat_messages(thread_id,sender_id,body) values('${thread}','${buyer}','Is the cocktail set available?')`);
  ok('normal chat message is accepted', (await rows(`select 1 from chat_messages where body like 'Is the cocktail%'`)).length === 1);
  await blocked('product review with explicit text is rejected',
    `insert into product_reviews(product_id,shop_id,buyer_id,rating,review_text) values(gen_random_uuid(),'${shop}','${buyer}',1,'porn')`);
  await blocked('shop review with profanity is rejected',
    `insert into shop_reviews(shop_id,buyer_id,rating,review_text) values('${shop}','${buyer}',1,'fucking awful')`);
  await blocked('profile display name with a slur is rejected', `update profiles set display_name='Retard' where id='${buyer}'`);
  await db.exec(`update profiles set display_name='Thandi' where id='${buyer}'`);
  ok('normal display name change is accepted', (await rows(`select display_name from profiles where id='${buyer}'`))[0].display_name === 'Thandi');
  await as(maker);
  await blocked('post caption is filtered', `insert into shop_posts(id,shop_id,caption) values(gen_random_uuid(),'${shop}','cunt')`);
  await blocked('tutorial step captions are filtered',
    `insert into shop_posts(id,shop_id,caption,step_captions) values(gen_random_uuid(),'${shop}','Steps','["Knead","fuck it"]')`);
  await blocked('story caption is filtered', `insert into shop_stories(shop_id,caption) values('${shop}','slut')`);
  await blocked('poll question is filtered', `insert into post_polls(post_id,question,options) values('${post}','whore?','["a","b"]')`);
  await blocked('poll options are filtered', `insert into post_polls(post_id,question,options) values('${post}','Pick one','["Blue","faggot"]')`);
  await db.exec(`insert into post_polls(post_id,question,options) values('${post}','Which glaze?','["Spice","Cocktail"]')`);
  ok('normal poll is accepted', (await rows(`select 1 from post_polls`)).length === 1);
  await blocked('shop bio is filtered', `update shops set bio='porno pots' where id='${shop}'`);
  await blocked('shop name is filtered', `update shops set name='Fuck Studio' where id='${shop}'`);
  await db.exec(`update shops set brand_story='Made in Hancock' where id='${shop}'`);
  ok('normal shop edit is accepted', (await rows(`select brand_story from shops`))[0].brand_story === 'Made in Hancock');
  await db.exec(`reset role;set role service_role;`);
  await blocked('server-side writes are filtered too', `update shops set bio='kaffir' where id='${shop}'`);

  // ── Reports on reviews and messages ──
  await as(outsider);
  await db.exec(`insert into creator_content_reports(target_type,target_id,reason) values('product_review','${productReview}','harassment')`);
  const pr = (await rows(`select * from creator_content_reports where target_type='product_review'`))[0];
  ok('product review report snapshots text, author and shop',
    pr.target_text_snapshot === '2/5\nArrived chipped' && pr.target_owner_id === buyer && pr.target_shop_id === shop && pr.reporter_id === outsider);
  await db.exec(`insert into creator_content_reports(target_type,target_id,reason) values('shop_review','${shopReview}','spam')`);
  const sr = (await rows(`select * from creator_content_reports where target_type='shop_review'`))[0];
  ok('shop review report snapshots text, author and shop',
    sr.target_text_snapshot === '5/5\nLovely maker' && sr.target_owner_id === buyer && sr.target_shop_id === shop);
  await denied('a non-participant cannot report a chat message',
    `insert into creator_content_reports(target_type,target_id,reason) values('message','${message}','spam')`);
  await denied('unknown review ids cannot be reported',
    `insert into creator_content_reports(target_type,target_id,reason) values('product_review',gen_random_uuid(),'spam')`);
  await as(admin);
  await denied('admins who can read a thread are still not participants for reporting',
    `insert into creator_content_reports(target_type,target_id,reason) values('message','${message}','spam')`);
  await as(buyer);
  await db.exec(`insert into creator_content_reports(target_type,target_id,reason,details) values('message','${message}','spam',' off-app payment ')`);
  const mr = (await rows(`select * from creator_content_reports where target_type='message'`))[0];
  ok('a participant can report a message; snapshot and sender are stamped',
    mr.target_text_snapshot === 'Pay me off the app' && mr.target_owner_id === maker && mr.target_shop_id === shop && mr.details === 'off-app payment');
  await denied('unknown target types are still rejected',
    `insert into creator_content_reports(target_type,target_id,reason) values('order','${message}','spam')`);
  await db.exec(`reset role;set role service_role;update creator_content_reports set status='resolved',reviewed_by='${admin}' where id='${mr.id}'`);
  ok('service-role resolution keeps the reviewing admin', (await rows(`select reviewed_by from creator_content_reports where id='${mr.id}'`))[0].reviewed_by === admin);
  await denied('reports stay immutable', `update creator_content_reports set target_text_snapshot='x' where id='${mr.id}'`);
  await db.exec(`insert into moderation_actions(admin_id,action,target_type,target_id) values
    ('${admin}','delete_product_review','product_review','${productReview}'),
    ('${admin}','delete_shop_review','shop_review','${shopReview}'),
    ('${admin}','delete_message','message','${message}')`);
  ok('moderation log accepts review and message takedowns', (await rows(`select 1 from moderation_actions`)).length === 3);

  // ── Community guidelines ──
  await as(null);
  await denied('guests cannot accept guidelines', `select public.accept_community_guidelines()`);
  await as(buyer);
  await denied('members cannot set the acceptance column directly',
    `update profiles set community_guidelines_accepted_at=now() where id='${buyer}'`);
  ok('acceptance starts empty', (await rows(`select public.get_my_community_guidelines_acceptance() as at`))[0].at === null);
  const first = (await rows(`select public.accept_community_guidelines() as at`))[0].at;
  ok('the RPC records acceptance', first instanceof Date);
  const again = (await rows(`select public.accept_community_guidelines() as at`))[0].at;
  ok('accepting again keeps the original time', again.getTime() === first.getTime());
  ok('the caller reads their own acceptance', (await rows(`select public.get_my_community_guidelines_acceptance() as at`))[0].at.getTime() === first.getTime());
  await db.exec('reset role');
  const accepted = await rows(`select id from profiles where community_guidelines_accepted_at is not null`);
  ok('only the caller\'s own row was set', accepted.length === 1 && accepted[0].id === buyer);
  await as(maker);
  ok('other members see only their own (empty) acceptance', (await rows(`select public.get_my_community_guidelines_acceptance() as at`))[0].at === null);

  // Seller listings are filtered too.
  await as(maker);
  await blocked('a listing title with a slur is blocked', `insert into products(shop_id,title) values('${shop}','Faggot doll')`);
  await blocked('a listing description with explicit terms is blocked', `insert into products(shop_id,title,description) values('${shop}','Mug','porn mug')`);
  await db.exec(`insert into products(shop_id,title,description) values('${shop}','Cocktail glasses','Hand blown Scunthorpe glass')`);
  ok('a normal listing is accepted', (await rows(`select count(*)::int n from products where title='Cocktail glasses'`))[0].n === 1);

  console.log(`${passed} UGC safety assertions passed`);
} catch (error) { console.error(error.message); process.exitCode = 1; } finally { await db.close(); }
