// Isolated PostgreSQL policy tests. No network or production database access.
// npm install --prefix .codex/story-db-validation --no-save --ignore-scripts @electric-sql/pglite@0.5.8
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const owner='10000000-0000-0000-0000-000000000001';
const other='10000000-0000-0000-0000-000000000002';
const shop='20000000-0000-0000-0000-000000000001';
const story='30000000-0000-0000-0000-000000000001';
let passed=0;
const ok=(label,value)=>{assert.ok(value,label); console.log('PASS '+label); passed++;};
async function denied(label,sql){let error;try{await db.exec(sql);}catch(e){error=e;}ok(label,!!error);}
async function asUser(id){await db.exec(`reset role; set role ${id?'authenticated':'anon'}; select set_config('test.uid','${id??''}',false);`);}
try {
 await db.exec(`create role anon; create role authenticated; create schema auth; create schema storage;
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
 grant usage on schema auth,storage,public to anon,authenticated;
 create table public.profiles(id uuid primary key);
 create table public.shops(id uuid primary key,vendor_id uuid references public.profiles(id),is_active boolean,is_offline boolean);
 grant select on public.shops to anon,authenticated;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
 alter table storage.objects enable row level security;
 grant select,insert,delete on storage.objects to anon,authenticated;
 insert into public.profiles values('${owner}'),('${other}');
 insert into public.shops values('${shop}','${owner}',true,false);`);
 await db.exec(readFileSync(new URL('../supabase/migrations/20260922210020_creator_stories.sql',import.meta.url),'utf8'));
 await asUser(other);
 await denied('non-maker cannot upload',`insert into storage.objects(bucket_id,name) values('creator-stories','${other}/x.jpg')`);
 await asUser(owner);
 await denied('owner cannot upload to another user folder',`insert into storage.objects(bucket_id,name) values('creator-stories','${other}/x.jpg')`);
 await db.exec(`insert into storage.objects(bucket_id,name) values('creator-stories','${owner}/x.jpg');
 insert into public.shop_stories(id,shop_id,media_path,media_type,created_at,expires_at)
 values('${story}','${shop}','${owner}/x.jpg','image','2100-01-01','2100-01-02');`);
 const time=(await db.query(`select created_at<now()+interval '1 minute' and expires_at-created_at=interval '24 hours' as valid from public.shop_stories`)).rows[0];
 ok('server overrides supplied times and enforces 24 hours',time.valid);
 const beforeRetry=(await db.query('select extract(epoch from expires_at) as expiry from public.shop_stories')).rows[0].expiry;
 await db.exec(`insert into public.shop_stories(id,shop_id,media_path,media_type) values('${story}','${shop}','${owner}/x.jpg','image') on conflict(id) do nothing;`);
 ok('publication retry does not duplicate a story',(await db.query('select * from public.shop_stories')).rows.length===1);
 ok('publication retry does not extend expiry',(await db.query('select extract(epoch from expires_at) as expiry from public.shop_stories')).rows[0].expiry===beforeRetry);
 await denied('owner cannot extend a story',`update public.shop_stories set expires_at=now()+interval '10 days'`);
 await asUser(other);
 await denied('cannot publish for another maker',`insert into public.shop_stories(shop_id,media_path,media_type) values('${shop}','${other}/x.jpg','image')`);
 ok('active stories visible to signed-in viewers',(await db.query('select * from public.shop_stories')).rows.length===1);
 ok('cross-owner delete affects no rows',(await db.query(`delete from public.shop_stories returning id`)).rows.length===0);
 await denied('cannot forge another viewer',`insert into public.shop_story_views(user_id,story_id) values('${owner}','${story}')`);
 await db.exec(`insert into public.shop_story_views(user_id,story_id) values('${other}','${story}') on conflict do nothing;
 insert into public.shop_story_views(user_id,story_id) values('${other}','${story}') on conflict do nothing;`);
 ok('seen writes are idempotent',(await db.query('select * from public.shop_story_views')).rows.length===1);
 await asUser(owner);
 ok('view receipts are account private',(await db.query('select * from public.shop_story_views')).rows.length===0);
 await asUser(null);
 ok('guest can read active stories',(await db.query('select * from public.shop_stories')).rows.length===1);
 ok('guest can download active media',(await db.query('select * from storage.objects')).rows.length===1);
 await db.exec(`reset role; update public.shops set is_active=false;`);
 await asUser(other);
 ok('private test shop not exposed',(await db.query('select * from public.shop_stories')).rows.length===0);
 ok('private shop media not exposed',(await db.query('select * from storage.objects')).rows.length===0);
 await asUser(owner);
 ok('owner can preview private story',(await db.query('select * from public.shop_stories')).rows.length===1);
 await db.exec(`reset role; update public.shops set is_active=true;
 update public.shop_stories set created_at=now()-interval '25 hours',expires_at=now()-interval '1 hour';`);
 await asUser(other);
 ok('expired story hidden by RLS',(await db.query('select * from public.shop_stories')).rows.length===0);
 ok('expired media hidden by RLS',(await db.query('select * from storage.objects')).rows.length===0);
 console.log(`${passed} policy assertions passed.`);
} catch (error) { console.error(error.message); process.exitCode=1; }
finally { await db.close(); }
