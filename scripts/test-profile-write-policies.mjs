import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
const a='10000000-0000-0000-0000-000000000001',b='10000000-0000-0000-0000-000000000002',c='10000000-0000-0000-0000-000000000003';
let passed=0;
const ok=(label,value)=>{assert.ok(value,label);console.log('PASS '+label);passed++;};
async function denied(label,sql){let err;try{await db.exec(sql);}catch(e){err=e;}ok(label,!!err);}
async function asUser(id){await db.exec(`reset role;set role ${id?'authenticated':'anon'};select set_config('test.uid','${id??''}',false);`);}
try {
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 grant usage on schema auth,public to anon,authenticated,service_role;
 create table profiles(id uuid primary key,role text not null default 'buyer',display_name text,email text,
 phone text,avatar_url text,shipping_addresses jsonb default '[]',vendor_approved_seen_at timestamptz,
 tradesafe_token_id text,admin_role text default 'none',user_role text default 'consumer',
 is_verified_host boolean default false,onboarding_status text default 'draft',onboarding_last_note text,
 onboarding_reviewed_at timestamptz,created_at timestamptz default now(),updated_at timestamptz default now());
 alter table profiles enable row level security;
 grant all on profiles to anon,authenticated,service_role;
 create policy demo_profiles_all on profiles for all using(true) with check(true);
 insert into profiles(id,role,display_name) values('${a}','buyer','Buyer'),('${b}','vendor','Maker');`);
 await db.exec(readFileSync(new URL('../supabase/migrations/20260925092917_harden_profile_writes.sql',import.meta.url),'utf8'));
 await asUser(null);
 await denied('guest cannot edit accounts',`update profiles set role='admin' where id='${a}'`);
 await denied('guest cannot create privileged account',`insert into profiles(id,role) values('${c}','admin')`);
 await asUser(a);
 await db.exec(`update profiles set display_name='Changed',phone='0123' where id='${a}'`);
 ok('owner can edit contact/display fields',(await db.query(`select display_name from profiles where id='${a}'`)).rows[0].display_name==='Changed');
 await denied('owner cannot promote self',`update profiles set role='admin' where id='${a}'`);
 await denied('owner cannot set alternate admin role',`update profiles set admin_role='admin' where id='${a}'`);
 await denied('owner cannot forge payment identity',`update profiles set tradesafe_token_id='fake' where id='${a}'`);
 await denied('owner cannot forge approval',`update profiles set is_verified_host=true where id='${a}'`);
 await denied('owner cannot change creation audit',`update profiles set created_at='2000-01-01' where id='${a}'`);
 await db.exec(`update profiles set display_name='Attacker' where id='${b}'`);
 ok('foreign row update blocked',(await db.query(`select display_name from profiles where id='${b}'`)).rows[0].display_name==='Maker');
 await denied('profile deletion requires server',`delete from profiles where id='${a}'`);
 await asUser(b);
 await db.exec(`insert into profiles(id,role,display_name) values('${b}','vendor','Returning maker') on conflict(id) do update set role=excluded.role,display_name=excluded.display_name`);
 ok('approved vendor sign-in upsert preserves role',(await db.query(`select role from profiles where id='${b}'`)).rows[0].role==='vendor');
 await denied('upsert cannot elevate a vendor',`insert into profiles(id,role) values('${b}','admin') on conflict(id) do update set role=excluded.role`);
 await asUser(c);
 await denied('new profile cannot self-approve',`insert into profiles(id,role) values('${c}','vendor')`);
 await db.exec(`insert into profiles(id,display_name) values('${c}','New buyer')`);
 ok('normal signup remains available',(await db.query(`select role from profiles where id='${c}'`)).rows[0].role==='buyer');
 await db.exec(`reset role;set role service_role;update profiles set role='vendor' where id='${c}'`);
 ok('trusted server approval remains available',(await db.query(`select role from profiles where id='${c}'`)).rows[0].role==='vendor');
 console.log(`${passed} profile write assertions passed`);
} finally {await db.close();}
