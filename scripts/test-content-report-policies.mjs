// Isolated PostgreSQL tests; never connects to the live project.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const buyer = '10000000-0000-0000-0000-000000000001', other = '10000000-0000-0000-0000-000000000002', admin = '10000000-0000-0000-0000-000000000003';
const post = '20000000-0000-0000-0000-000000000001', hiddenPost = '20000000-0000-0000-0000-000000000002', comment = '30000000-0000-0000-0000-000000000001', story = '40000000-0000-0000-0000-000000000001';
let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log(`PASS ${label}`); passed++; };
async function denied(label, sql) { let error; try { await db.exec(sql); } catch (caught) { error = caught; } ok(label, !!error); }
async function asUser(id) { await db.exec(`reset role; set role ${id ? 'authenticated' : 'anon'}; select set_config('test.uid','${id ?? ''}',false);`); }
try {
  await db.exec(`
    create role anon; create role authenticated; create schema auth;
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
    grant usage on schema auth, public to anon, authenticated;
    create table public.profiles(id uuid primary key, role text not null);
    create function public.current_user_is_admin() returns boolean language sql stable as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin') $$;
    create table public.shops(id uuid primary key, vendor_id uuid not null references public.profiles(id));
    create table public.shop_posts(id uuid primary key, shop_id uuid not null references public.shops(id), caption text, is_published boolean not null);
    create table public.shop_post_comments(id uuid primary key, post_id uuid not null references public.shop_posts(id), body text not null);
    create table public.shop_stories(id uuid primary key, shop_id uuid not null references public.shops(id), caption text, expires_at timestamptz not null);
    alter table public.shop_posts enable row level security; alter table public.shop_post_comments enable row level security; alter table public.shop_stories enable row level security;
    create policy visible_posts on public.shop_posts for select using (is_published);
    create policy visible_comments on public.shop_post_comments for select using (exists(select 1 from public.shop_posts p where p.id=post_id));
    create policy visible_stories on public.shop_stories for select using (expires_at > now());
    grant select on public.profiles, public.shops, public.shop_posts, public.shop_post_comments, public.shop_stories to anon, authenticated;
    insert into public.profiles values ('${buyer}','buyer'),('${other}','buyer'),('${admin}','admin');
    insert into public.shops values ('90000000-0000-0000-0000-000000000001','${other}');
    insert into public.shop_posts values ('${post}','90000000-0000-0000-0000-000000000001','Published caption',true),('${hiddenPost}','90000000-0000-0000-0000-000000000001','Hidden caption',false);
    insert into public.shop_posts select ('50000000-0000-0000-0000-' || lpad(gs::text, 12, '0'))::uuid, '90000000-0000-0000-0000-000000000001', 'Rate caption', true from generate_series(10,20) as gs;
    insert into public.shop_post_comments values ('${comment}','${post}','Reported comment'); insert into public.shop_stories values ('${story}','90000000-0000-0000-0000-000000000001','Story caption',now()+interval '1 hour');
  `);
  await db.exec(readFileSync(new URL('../supabase/migrations/20260925092400_creator_content_reports.sql', import.meta.url), 'utf8'));
  await asUser(null);
  await denied('guest cannot report', `insert into creator_content_reports(target_type,target_id,reason) values('post','${post}','spam')`);
  await asUser(buyer);
  await db.exec(`insert into creator_content_reports(target_type,target_id,reason,details) values('comment','${comment}','harassment','  unwanted messages  ')`);
  const receipt = (await db.query('select * from creator_content_reports')).rows[0];
  ok('reporter and immutable target snapshot are server stamped', receipt.reporter_id === buyer && receipt.details === 'unwanted messages' && receipt.target_text_snapshot === 'Reported comment' && receipt.target_owner_id === other && receipt.status === 'open');
  await denied('duplicate target receipt is rejected', `insert into creator_content_reports(target_type,target_id,reason) values('comment','${comment}','spam')`);
  await denied('hidden target cannot be reported', `insert into creator_content_reports(target_type,target_id,reason) values('post','${hiddenPost}','spam')`);
  await asUser(other); ok('reporter receipts stay private', (await db.query('select * from creator_content_reports')).rows.length === 0);
  await asUser(admin); ok('admin can review the queue', (await db.query('select * from creator_content_reports')).rows.length === 1);
  await db.exec(`update creator_content_reports set status='resolved',resolution_notes='Reviewed' returning id`);
  const resolved = (await db.query('select * from creator_content_reports')).rows[0];
  ok('resolution is audited without changing content', resolved.status === 'resolved' && resolved.reviewed_by === admin && resolved.reviewed_at !== null);
  await denied('immutable target cannot be changed', `update creator_content_reports set target_id='${post}'`);
  await asUser(buyer);
  ok('reporter cannot resolve their own report', (await db.query(`update creator_content_reports set status='dismissed' returning id`)).rows.length === 0);
  for (let i = 10; i < 19; i++) { const id = `50000000-0000-0000-0000-${String(i).padStart(12, '0')}`; await db.exec(`insert into creator_content_reports(target_type,target_id,reason) values('post','${id}','spam')`); }
  let duplicateError; try { await db.exec(`insert into creator_content_reports(target_type,target_id,reason) values('comment','${comment}','spam')`); } catch (error) { duplicateError = error; }
  ok('duplicate retry at the cap is not rate limited', duplicateError && !String(duplicateError.message).includes('Too many reports'));
  const rateTarget = '50000000-0000-0000-0000-000000000020';
  await denied('hourly report creation is capped', `insert into creator_content_reports(target_type,target_id,reason) values('post','${rateTarget}','spam')`);
  console.log(`${passed} policy assertions passed.`);
} catch (error) { console.error(error.message); process.exitCode = 1; } finally { await db.close(); }
