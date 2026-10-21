// Isolated PostgreSQL tests for
// 20261021090000_hide_chat_threads_and_dismiss_notifications.sql; never
// connects to the live project. Mirrors the live chat tables, applies the real
// notifications migration (058), then the inbox tidy-up migration.
import { PGlite } from '../.codex/story-db-validation/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const buyer = '10000000-0000-0000-0000-000000000001', maker = '10000000-0000-0000-0000-000000000002',
  outsider = '10000000-0000-0000-0000-000000000003', shop = '20000000-0000-0000-0000-000000000001',
  thread = '50000000-0000-0000-0000-000000000001', quietThread = '50000000-0000-0000-0000-000000000002';
let passed = 0;
const ok = (label, value) => { assert.ok(value, label); console.log('PASS ' + label); passed++; };
async function failure(sql) { try { await db.exec(sql); } catch (e) { return e; } return null; }
async function denied(label, sql) { ok(label, !!(await failure(sql))); }
const rows = async sql => (await db.query(sql)).rows;
const migration = name => readFileSync(new URL(`../supabase/migrations/${name}`, import.meta.url), 'utf8');
async function as(id) { await db.exec(`reset role;set role ${id ? 'authenticated' : 'anon'};select set_config('test.uid','${id ?? ''}',false);`); }
// What the app's inbox query (`hidden_for_me=eq.false`) returns for the caller.
const inbox = async column => (await rows(
  `select t.id from chat_threads t where t.${column}=auth.uid() and public.hidden_for_me(t)=false order by t.id`)).map(r => r.id);
async function say(sender, body) {
  await as(sender);
  await db.exec(`insert into chat_messages(thread_id,sender_id,body,created_at) values('${thread}','${sender}','${body}',clock_timestamp())`);
}

try {
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  grant usage on schema auth,public to anon,authenticated,service_role;
  -- Supabase grants table and function access to the API roles by default.
  alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
  alter default privileges in schema public grant all on functions to anon,authenticated,service_role;
  create table profiles(id uuid primary key,role text not null default 'buyer',display_name text);
  create table shops(id uuid primary key,vendor_id uuid not null,name text not null);
  create table chat_threads(id uuid primary key default gen_random_uuid(),shop_id uuid references shops(id),
    buyer_id uuid not null references profiles(id),vendor_id uuid not null references profiles(id),
    kind text not null default 'buyer_vendor',last_message_preview text,last_message_at timestamptz,
    created_at timestamptz not null default now(),updated_at timestamptz not null default now());
  create table chat_messages(id uuid primary key default gen_random_uuid(),
    thread_id uuid not null references chat_threads(id) on delete cascade,sender_id uuid not null references profiles(id),
    body text,created_at timestamptz not null default now());
  create function public.is_chat_thread_participant(thread_uuid uuid) returns boolean language sql stable as
    $$select exists(select 1 from public.chat_threads t where t.id=thread_uuid and (t.buyer_id=auth.uid() or t.vendor_id=auth.uid()))$$;
  -- Same bookkeeping as 021's touch_chat_thread_on_message (security definer
  -- here because the mirror has no participant update policy).
  create function public.touch_chat_thread_on_message() returns trigger language plpgsql security definer as $$
  begin update public.chat_threads set last_message_preview=left(trim(new.body),120),last_message_at=new.created_at,
    updated_at=now() where id=new.thread_id; return new; end $$;
  create trigger touch_chat_thread_on_message_trigger after insert on chat_messages
    for each row execute function public.touch_chat_thread_on_message();
  alter table chat_threads enable row level security; alter table chat_messages enable row level security;
  create policy threads_read on chat_threads for select using (buyer_id=auth.uid() or vendor_id=auth.uid());
  create policy messages_read on chat_messages for select using (public.is_chat_thread_participant(thread_id));
  create policy messages_write on chat_messages for insert with check (sender_id=auth.uid() and public.is_chat_thread_participant(thread_id));
  insert into profiles values('${buyer}','buyer','Buyer'),('${maker}','vendor','Maker'),('${outsider}','buyer','Outsider');
  insert into shops values('${shop}','${maker}','Lobby Cape Town');
  insert into chat_threads(id,shop_id,buyer_id,vendor_id,created_at)
    values('${thread}','${shop}','${buyer}','${maker}',now()-interval '2 days'),
          ('${quietThread}','${shop}','${outsider}','${maker}',now()-interval '1 day');`);
  await db.exec(migration('058_add_persisted_notifications.sql'));
  await db.exec(migration('20261021090000_hide_chat_threads_and_dismiss_notifications.sql'));

  // ── Hiding a conversation ───────────────────────────────────────
  await say(maker, 'New order placed');
  await say(buyer, 'Thanks!');

  await as(buyer);
  ok('the conversation starts in the buyer inbox', (await inbox('buyer_id')).includes(thread));
  ok('a participant can hide a conversation', (await rows(`select public.hide_chat_thread('${thread}') as at`))[0].at != null);
  ok('it leaves the buyer inbox', !(await inbox('buyer_id')).includes(thread));
  ok('hiding twice is fine', (await rows(`select public.hide_chat_thread('${thread}') as at`))[0].at != null);
  ok('no messages were removed', (await rows(`select count(*)::int n from chat_messages where thread_id='${thread}'`))[0].n === 2);
  ok('the buyer can still open the thread directly', (await rows(`select id from chat_threads where id='${thread}'`)).length === 1);

  await as(maker);
  ok('the artisan still sees it', (await inbox('vendor_id')).includes(thread));
  ok('the artisan cannot see the buyer hide row', (await rows(`select * from chat_thread_hidden`)).length === 0);

  await say(maker, 'Your parcel ships tomorrow');
  await as(buyer);
  ok('a newer message brings it back for the buyer', (await inbox('buyer_id')).includes(thread));

  await as(maker);
  await db.exec(`select public.hide_chat_thread('${thread}')`);
  ok('the artisan can hide it on their side', !(await inbox('vendor_id')).includes(thread));
  ok('their other conversations stay', (await inbox('vendor_id')).includes(quietThread));
  await as(buyer);
  ok("the artisan hiding it does not affect the buyer", (await inbox('buyer_id')).includes(thread));

  await as(outsider);
  await denied('a non-participant cannot hide someone else\'s conversation', `select public.hide_chat_thread('${thread}')`);
  await denied('an unknown thread cannot be hidden', `select public.hide_chat_thread(gen_random_uuid())`);
  await denied('hide rows cannot be inserted directly', `insert into chat_thread_hidden(thread_id,user_id) values('${quietThread}','${outsider}')`);
  await as(null);
  await denied('a guest cannot hide conversations', `select public.hide_chat_thread('${thread}')`);
  await denied('a guest cannot read hide rows', `select * from chat_thread_hidden`);

  await as(maker);
  await db.exec(`update chat_thread_hidden set hidden_at=now()+interval '1 year' where user_id='${maker}'`).catch(() => {});
  ok('hide times cannot be pushed into the future', (await rows(
    `select count(*)::int n from chat_thread_hidden where hidden_at>now()+interval '1 day'`))[0].n === 0);
  await as(buyer);
  await db.exec(`delete from chat_thread_hidden where user_id='${maker}'`);
  await as(maker);
  ok("a buyer cannot un-hide the artisan's row", (await rows(`select count(*)::int n from chat_thread_hidden`))[0].n === 1);
  await db.exec(`delete from chat_thread_hidden where thread_id='${thread}'`);
  ok('people can un-hide their own conversation', (await inbox('vendor_id')).includes(thread));

  // ── Notifications ───────────────────────────────────────────────
  await db.exec(`reset role;insert into notifications(user_id,title,event_key) values
    ('${buyer}','Order shipped','order:1:shipped'),('${buyer}','New message','chat:1'),('${maker}','New order','order:1:new');`);
  await as(buyer);
  await db.exec(`update notifications set read_at=now() where user_id=auth.uid() and read_at is null`);
  ok('mark all as read covers every own notification', (await rows(
    `select count(*)::int n from notifications where read_at is null`))[0].n === 0);
  await db.exec(`update notifications set dismissed_at=now() where user_id=auth.uid() and dismissed_at is null`);
  ok('clear all dismisses own notifications', (await rows(
    `select count(*)::int n from notifications where dismissed_at is null`))[0].n === 0);
  await db.exec(`update notifications set read_at=now(),dismissed_at=now() where user_id='${maker}'`);
  await as(maker);
  ok("a buyer cannot read or clear the artisan's notifications", (await rows(
    `select count(*)::int n from notifications where read_at is null and dismissed_at is null`))[0].n === 1);
  await db.exec(`reset role;insert into notifications(user_id,title,event_key) values('${buyer}','Order shipped','order:1:shipped')
    on conflict (user_id,event_key) do nothing`);
  ok('a cleared notification is not re-created by a repeat event', (await rows(
    `select count(*)::int n from notifications where user_id='${buyer}' and dismissed_at is null`))[0].n === 0);

  console.log(`${passed} inbox tidy-up assertions passed`);
} catch (error) { console.error(error.message); process.exitCode = 1; } finally { await db.close(); }
