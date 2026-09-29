// Isolated database only: no remote credentials or project writes.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const a='10000000-0000-0000-0000-000000000001', b='10000000-0000-0000-0000-000000000002';
const p='20000000-0000-0000-0000-000000000001', q='20000000-0000-0000-0000-000000000002';
let checks=0;
const ok=(label,value)=>{assert.ok(value,label); console.log('PASS '+label);checks++;};
async function denied(label,sql){let error;try{await db.exec(sql);}catch(e){error=e;}ok(label,!!error);}
async function asUser(id){await db.exec(`reset role;set role ${id?'authenticated':'anon'};select set_config('test.uid','${id??''}',false);`);}
try {
 await db.exec(`create role anon;create role authenticated;create schema auth;
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
 grant usage on schema auth,public to anon,authenticated;
 create table profiles(id uuid primary key);create table products(id uuid primary key);
 insert into profiles values('${a}'),('${b}');insert into products values('${p}'),('${q}');`);
 await db.exec(readFileSync(new URL('../supabase/migrations/20260925091906_creator_discovery_sync.sql',import.meta.url),'utf8'));
 await asUser(null);
 await denied('guests cannot read preferences','select * from discovery_choices');
 await denied('guests cannot read swipe history','select * from discovery_product_decisions');
 await asUser(a);
 await db.exec(`insert into discovery_choices(user_id,max_budget) values('${a}',500);
 insert into discovery_product_decisions values('${a}','${p}',true);`);
 ok('owner reads own choices',(await db.query('select * from discovery_choices')).rows.length===1);
 await denied('cannot create another user preferences',`insert into discovery_choices(user_id) values('${b}')`);
 await denied('cannot transfer ownership',`update discovery_choices set user_id='${b}'`);
 await denied('invalid budget rejected',`update discovery_choices set max_budget=-1`);
 await denied('cannot forge another users swipe',`insert into discovery_product_decisions values('${b}','${q}',true)`);
 await denied('cannot move a swipe to another account',`update discovery_product_decisions set user_id='${b}'`);
 await asUser(b);
 ok('other user sees no preferences',(await db.query('select * from discovery_choices')).rows.length===0);
 ok('other user sees no decisions',(await db.query('select * from discovery_product_decisions')).rows.length===0);
 await db.exec(`delete from discovery_choices where user_id='${a}';update discovery_product_decisions set liked=false where user_id='${a}';`);
 await asUser(a);
 ok('foreign delete was blocked',(await db.query('select * from discovery_choices')).rows.length===1);
 ok('foreign update was blocked',(await db.query('select liked from discovery_product_decisions')).rows[0].liked===true);
 await db.exec(`insert into discovery_product_decisions values('${a}','${q}',false);
 update discovery_choices set max_budget=700 where user_id='${a}';`);
 ok('independent decisions survive preference edits',(await db.query('select * from discovery_product_decisions')).rows.length===2);
 await db.exec(`insert into discovery_product_decisions values('${a}','${p}',false) on conflict(user_id,product_id) do nothing`);
 ok('legacy import does not replace a cloud choice',(await db.query(`select liked from discovery_product_decisions where product_id='${p}'`)).rows[0].liked===true);
 console.log(`${checks} discovery policy assertions passed`);
} finally {await db.close();}
