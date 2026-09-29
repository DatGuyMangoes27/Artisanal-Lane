// Isolated policy checks; does not contact Supabase or mutate a linked project.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const owner='10000000-0000-0000-0000-000000000001', other='10000000-0000-0000-0000-000000000002', shop='20000000-0000-0000-0000-000000000001';
const path=`${owner}/30000000-0000-0000-0000-000000000001.mp4`, marker=`artisan-post://${path}`;
let passed=0; const ok=(label,value)=>{assert.ok(value,label);console.log('PASS '+label);passed++;};
async function asUser(id){await db.exec(`reset role; set role ${id?'authenticated':'anon'}; select set_config('test.uid','${id??''}',false);`);}
async function denied(label,sql){let error;try{await db.exec(sql);}catch(e){error=e;}ok(label,!!error);}
try {
 await db.exec(`create role anon; create role authenticated; create schema auth; create schema storage;
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 create table public.shops(id uuid primary key,vendor_id uuid,is_active boolean,is_offline boolean);
 create table public.shop_posts(id uuid primary key default gen_random_uuid(),shop_id uuid,is_published boolean,media_urls jsonb not null default '[]');
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
 alter table storage.objects enable row level security; grant usage on schema auth,storage,public to anon,authenticated;
 grant select on public.shops,public.shop_posts to anon,authenticated; grant select,insert,update,delete on storage.objects to anon,authenticated;
 insert into public.shops values('${shop}','${owner}',true,false); create policy legacy_open on storage.objects for all using(true) with check(true);`);
 await db.exec(readFileSync(new URL('../supabase/migrations/20260925092610_add_private_creator_post_media.sql',import.meta.url),'utf8'));
 await asUser(other); await db.exec(`insert into storage.objects(bucket_id,name)values('unrelated','legacy-still-works')`);
 ok('restrictive guards do not block unrelated legacy bucket',(await db.query(`select * from storage.objects where bucket_id='unrelated'`)).rows.length===1);
 await asUser(null); await denied('anonymous cannot upload private video',`insert into storage.objects(bucket_id,name)values('creator-post-media','${path}')`);
 await asUser(other); await denied('non-owner cannot upload',`insert into storage.objects(bucket_id,name)values('creator-post-media','${other}/30000000-0000-0000-0000-000000000001.mp4')`);
 await asUser(owner); await denied('owner cannot upload outside UUID path',`insert into storage.objects(bucket_id,name)values('creator-post-media','${owner}/bad.mp4')`);
 await db.exec(`insert into storage.objects(bucket_id,name)values('creator-post-media','${path}')`);
 await asUser(null); ok('anonymous cannot delete private video',(await db.query(`delete from storage.objects where bucket_id='creator-post-media' returning id`)).rows.length===0);
 await asUser(owner); ok('legacy UPDATE cannot mutate private video',(await db.query(`update storage.objects set name='${owner}/30000000-0000-0000-0000-000000000009.mp4' where bucket_id='creator-post-media' returning id`)).rows.length===0);
 await asUser(other); ok('unpublished private media is hidden',(await db.query(`select * from storage.objects where bucket_id='creator-post-media'`)).rows.length===0);
 await db.exec(`reset role; insert into public.shop_posts(shop_id,is_published,media_urls)values('${shop}',true,jsonb_build_array('${marker}'))`);
 await asUser(other); ok('published active post grants media read',(await db.query(`select * from storage.objects where bucket_id='creator-post-media'`)).rows.length===1);
 await db.exec(`reset role; update public.shops set is_offline=true`); await asUser(other);
 ok('offline shop revokes media read',(await db.query(`select * from storage.objects where bucket_id='creator-post-media'`)).rows.length===0);
 await asUser(owner); ok('owner keeps draft preview',(await db.query(`select * from storage.objects where bucket_id='creator-post-media'`)).rows.length===1);
 await asUser(other); ok('cross-owner delete affects no rows',(await db.query(`delete from storage.objects where bucket_id='creator-post-media' returning id`)).rows.length===0);
 await db.exec(`reset role;
   insert into public.shops values('20000000-0000-0000-0000-000000000002','${other}',true,false);
   insert into public.shop_posts(shop_id,is_published,media_urls) values('20000000-0000-0000-0000-000000000002',true,jsonb_build_array('${marker}'));`);
 await asUser(null);
 ok('another maker cannot expose private media by tagging its path',(await db.query(`select * from storage.objects where bucket_id='creator-post-media'`)).rows.length===0);
 console.log(`${passed} policy assertions passed.`);
} catch(error){console.error(error.message);process.exitCode=1;} finally{await db.close();}

// The feature must also work when a project has no historic broad policy.
if (!process.exitCode) {
 const clean = new PGlite();
 try {
  await clean.exec(`create role anon; create role authenticated; create schema auth; create schema storage;
   create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
   create table public.shops(id uuid primary key,vendor_id uuid,is_active boolean,is_offline boolean);
   create table public.shop_posts(id uuid primary key default gen_random_uuid(),shop_id uuid,is_published boolean,media_urls jsonb not null default '[]');
   create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
   create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
   alter table storage.objects enable row level security; grant usage on schema auth,storage,public to anon,authenticated;
   grant select on public.shops,public.shop_posts to anon,authenticated; grant select,insert,update,delete on storage.objects to anon,authenticated;
   insert into public.shops values('${shop}','${owner}',true,false);`);
  await clean.exec(readFileSync(new URL('../supabase/migrations/20260925092610_add_private_creator_post_media.sql',import.meta.url),'utf8'));
  await clean.exec(`set role authenticated; select set_config('test.uid','${owner}',false); insert into storage.objects(bucket_id,name)values('creator-post-media','${path}')`);
  ok('standalone policies permit owner upload',(await clean.query(`select * from storage.objects`)).rows.length===1);
  await clean.exec(`reset role; insert into public.shop_posts(shop_id,is_published,media_urls)values('${shop}',true,jsonb_build_array('${marker}')); set role anon; select set_config('test.uid','',false);`);
  ok('standalone policies permit published viewer read',(await clean.query(`select * from storage.objects`)).rows.length===1);
 } catch(error){console.error(error.message);process.exitCode=1;} finally {await clean.close();}
}
