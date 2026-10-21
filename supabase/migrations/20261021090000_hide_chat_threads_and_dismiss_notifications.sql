-- ============================================================
-- Inbox tidy-up for buyers and artisans.
--
-- 1. "Delete conversation" hides a chat thread for the person who deleted
--    it only. Messages are never removed (they can matter in an order
--    dispute) and the other participant keeps the thread. When a newer
--    message arrives (last_message_at moves past hidden_at) the thread shows
--    up again automatically.
--
-- 2. Notifications can be cleared. Rows are soft-dismissed rather than
--    deleted, because the server uses (user_id, event_key) to avoid storing
--    or pushing the same event twice (send-push-notification upserts with
--    ignoreDuplicates, send-receipt-reminders skips existing event keys).
--    Deleting the row would let a cleared reminder come back.
-- ============================================================

-- ── 1. Per-person hidden chat threads ───────────────────────────
create table if not exists public.chat_thread_hidden (
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  hidden_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create index if not exists idx_chat_thread_hidden_user_id
  on public.chat_thread_hidden (user_id);

alter table public.chat_thread_hidden enable row level security;

-- Rows are written through hide_chat_thread() only, so hidden_at is always
-- the server time and only real participants can hide a thread. People may
-- read and remove (un-hide) their own rows.
revoke all on public.chat_thread_hidden from anon;
revoke insert, update on public.chat_thread_hidden from authenticated;
grant select, delete on public.chat_thread_hidden to authenticated;

drop policy if exists "Users can view own hidden chat threads" on public.chat_thread_hidden;
create policy "Users can view own hidden chat threads"
  on public.chat_thread_hidden for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users can unhide own chat threads" on public.chat_thread_hidden;
create policy "Users can unhide own chat threads"
  on public.chat_thread_hidden for delete
  to authenticated
  using (user_id = auth.uid());

create or replace function public.hide_chat_thread(thread_uuid uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
  hidden timestamptz := now();
begin
  if caller is null then
    raise exception 'Sign in to manage your messages.'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.chat_threads thread
    where thread.id = thread_uuid
      and (thread.buyer_id = caller or thread.vendor_id = caller)
  ) then
    raise exception 'Conversation not found.'
      using errcode = '42501';
  end if;

  insert into public.chat_thread_hidden (thread_id, user_id, hidden_at)
  values (thread_uuid, caller, hidden)
  on conflict (thread_id, user_id)
    do update set hidden_at = excluded.hidden_at;

  return hidden;
end;
$$;

revoke all on function public.hide_chat_thread(uuid) from public, anon;
grant execute on function public.hide_chat_thread(uuid) to authenticated;

-- PostgREST computed field: `?hidden_for_me=eq.false` keeps hidden threads
-- out of the signed-in person's inbox. A thread counts as hidden only while
-- nothing newer than the hide has been said in it.
create or replace function public.hidden_for_me(thread public.chat_threads)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_thread_hidden hidden
    where hidden.thread_id = thread.id
      and hidden.user_id = auth.uid()
      and hidden.hidden_at >= coalesce(thread.last_message_at, thread.created_at)
  );
$$;

revoke all on function public.hidden_for_me(public.chat_threads) from public, anon;
grant execute on function public.hidden_for_me(public.chat_threads) to authenticated;

-- ── 2. Clearable notifications ──────────────────────────────────
alter table public.notifications
  add column if not exists dismissed_at timestamptz;

create index if not exists idx_notifications_user_visible
  on public.notifications (user_id, created_at desc)
  where dismissed_at is null;

-- The existing "Users can update own notifications" policy already limits
-- read_at / dismissed_at writes to the owner's rows.
