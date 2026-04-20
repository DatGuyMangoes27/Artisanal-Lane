-- ============================================================
-- Admin <-> Shop chat threads.
--
-- We reuse the existing chat_threads / chat_messages infrastructure so the
-- vendor's inbox, realtime streams, read-receipts, and attachment plumbing
-- all continue to work without duplication.
--
-- A new `kind` column differentiates an admin conversation from a regular
-- buyer<->vendor conversation. For admin threads:
--   * kind           = 'admin_vendor'
--   * buyer_id       = the admin profile id (participant on the admin side)
--   * vendor_id      = the shop's vendor (set by the existing trigger)
--
-- Admin-panel operations are performed with the service-role key, so they
-- bypass RLS; we still add an "admin can read/write chat" policy so an admin
-- using the regular client (e.g. future admin Flutter build) is able to
-- access the chat data they need.
-- ============================================================

alter table public.chat_threads
  add column if not exists kind text not null default 'buyer_vendor';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chat_threads_kind_check'
  ) then
    alter table public.chat_threads
      add constraint chat_threads_kind_check
      check (kind in ('buyer_vendor', 'admin_vendor'));
  end if;
end
$$;

create index if not exists idx_chat_threads_kind
  on public.chat_threads (kind);

-- Helper: is the current user an admin profile?
create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  );
$$;

-- Extend the thread participant helper so admins count as participants on
-- every chat thread. This keeps message/reads RLS consistent whether the
-- thread is buyer<->vendor or admin<->vendor.
create or replace function public.is_chat_thread_participant(thread_uuid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.chat_threads thread
    where thread.id = thread_uuid
      and (
        thread.buyer_id = auth.uid()
        or thread.vendor_id = auth.uid()
        or public.current_user_is_admin()
      )
  );
$$;

-- Thread-level policies: allow admins to view every thread and to create
-- admin_vendor threads where they are the "buyer" (admin) participant.
drop policy if exists "Participants can view chat threads" on public.chat_threads;
create policy "Participants can view chat threads"
  on public.chat_threads for select
  using (
    buyer_id = auth.uid()
    or vendor_id = auth.uid()
    or public.current_user_is_admin()
  );

drop policy if exists "Buyers can create chat threads" on public.chat_threads;
create policy "Buyers can create chat threads"
  on public.chat_threads for insert
  with check (
    (
      kind = 'buyer_vendor'
      and buyer_id = auth.uid()
      and exists (
        select 1
        from public.shops s
        where s.id = shop_id
          and s.vendor_id = vendor_id
      )
    )
    or (
      kind = 'admin_vendor'
      and public.current_user_is_admin()
      and buyer_id = auth.uid()
    )
  );

drop policy if exists "Participants can update chat threads" on public.chat_threads;
create policy "Participants can update chat threads"
  on public.chat_threads for update
  using (
    buyer_id = auth.uid()
    or vendor_id = auth.uid()
    or public.current_user_is_admin()
  );

-- Chat attachment storage: allow admins to view/upload alongside the
-- existing participants. Keep the original participant policies by dropping
-- and recreating them with an extra admin branch.
drop policy if exists "Chat participants can view attachments" on storage.objects;
create policy "Chat participants can view attachments"
  on storage.objects for select
  using (
    bucket_id = 'chat-attachments'
    and (
      public.current_user_is_admin()
      or exists (
        select 1
        from public.chat_threads thread
        where thread.id::text = split_part(name, '/', 1)
          and (
            thread.buyer_id = auth.uid()
            or thread.vendor_id = auth.uid()
          )
      )
    )
  );

drop policy if exists "Chat participants can upload attachments" on storage.objects;
create policy "Chat participants can upload attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'chat-attachments'
    and (
      public.current_user_is_admin()
      or exists (
        select 1
        from public.chat_threads thread
        where thread.id::text = split_part(name, '/', 1)
          and (
            thread.buyer_id = auth.uid()
            or thread.vendor_id = auth.uid()
          )
      )
    )
  );

drop policy if exists "Chat participants can update attachments" on storage.objects;
create policy "Chat participants can update attachments"
  on storage.objects for update
  using (
    bucket_id = 'chat-attachments'
    and (
      public.current_user_is_admin()
      or exists (
        select 1
        from public.chat_threads thread
        where thread.id::text = split_part(name, '/', 1)
          and (
            thread.buyer_id = auth.uid()
            or thread.vendor_id = auth.uid()
          )
      )
    )
  );

drop policy if exists "Chat participants can delete attachments" on storage.objects;
create policy "Chat participants can delete attachments"
  on storage.objects for delete
  using (
    bucket_id = 'chat-attachments'
    and (
      public.current_user_is_admin()
      or exists (
        select 1
        from public.chat_threads thread
        where thread.id::text = split_part(name, '/', 1)
          and (
            thread.buyer_id = auth.uid()
            or thread.vendor_id = auth.uid()
          )
      )
    )
  );
