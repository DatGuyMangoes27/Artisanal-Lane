-- ============================================================
-- In-app chat between buyers and artisans
-- ============================================================

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  vendor_id uuid not null references public.profiles(id) on delete cascade,
  last_message_preview text,
  last_message_type text not null default 'text'
    check (last_message_type in ('text', 'attachment', 'text_with_attachment')),
  last_message_sender_id uuid references public.profiles(id) on delete set null,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, buyer_id)
);

create index if not exists idx_chat_threads_buyer_id
  on public.chat_threads (buyer_id, coalesce(last_message_at, created_at) desc);

create index if not exists idx_chat_threads_vendor_id
  on public.chat_threads (vendor_id, coalesce(last_message_at, created_at) desc);

create index if not exists idx_chat_threads_shop_id
  on public.chat_threads (shop_id);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text,
  message_type text not null default 'text'
    check (message_type in ('text', 'attachment', 'text_with_attachment')),
  attachment_url text,
  attachment_path text,
  attachment_name text,
  attachment_mime text,
  attachment_size_bytes bigint,
  created_at timestamptz not null default now(),
  check (
    coalesce(length(trim(body)), 0) > 0
    or attachment_path is not null
    or attachment_url is not null
  )
);

create index if not exists idx_chat_messages_thread_id
  on public.chat_messages (thread_id, created_at asc);

create index if not exists idx_chat_messages_sender_id
  on public.chat_messages (sender_id);

create table if not exists public.chat_thread_reads (
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  participant_id uuid not null references public.profiles(id) on delete cascade,
  last_read_message_id uuid references public.chat_messages(id) on delete set null,
  last_read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (thread_id, participant_id)
);

create index if not exists idx_chat_thread_reads_participant_id
  on public.chat_thread_reads (participant_id, updated_at desc);

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
      )
  );
$$;

create or replace function public.set_chat_thread_vendor_id()
returns trigger
language plpgsql
as $$
declare
  resolved_vendor_id uuid;
begin
  select s.vendor_id
  into resolved_vendor_id
  from public.shops s
  where s.id = new.shop_id;

  if resolved_vendor_id is null then
    raise exception 'Shop not found or has no vendor';
  end if;

  new.vendor_id := resolved_vendor_id;
  return new;
end;
$$;

create or replace function public.touch_chat_thread_on_message()
returns trigger
language plpgsql
as $$
begin
  update public.chat_threads
  set
    last_message_preview = case
      when new.body is not null and length(trim(new.body)) > 0 then left(trim(new.body), 120)
      when new.attachment_name is not null then new.attachment_name
      else 'Attachment'
    end,
    last_message_type = new.message_type,
    last_message_sender_id = new.sender_id,
    last_message_at = new.created_at,
    updated_at = now()
  where id = new.thread_id;

  return new;
end;
$$;

create or replace function public.seed_chat_thread_reads()
returns trigger
language plpgsql
as $$
begin
  insert into public.chat_thread_reads (thread_id, participant_id)
  values
    (new.id, new.buyer_id),
    (new.id, new.vendor_id)
  on conflict (thread_id, participant_id) do nothing;

  return new;
end;
$$;

drop trigger if exists set_chat_thread_vendor_id_trigger on public.chat_threads;
create trigger set_chat_thread_vendor_id_trigger
  before insert on public.chat_threads
  for each row execute function public.set_chat_thread_vendor_id();

drop trigger if exists seed_chat_thread_reads_trigger on public.chat_threads;
create trigger seed_chat_thread_reads_trigger
  after insert on public.chat_threads
  for each row execute function public.seed_chat_thread_reads();

drop trigger if exists touch_chat_thread_on_message_trigger on public.chat_messages;
create trigger touch_chat_thread_on_message_trigger
  after insert on public.chat_messages
  for each row execute function public.touch_chat_thread_on_message();

drop trigger if exists update_chat_threads_updated_at on public.chat_threads;
create trigger update_chat_threads_updated_at
  before update on public.chat_threads
  for each row execute function public.update_updated_at_column();

drop trigger if exists update_chat_thread_reads_updated_at on public.chat_thread_reads;
create trigger update_chat_thread_reads_updated_at
  before update on public.chat_thread_reads
  for each row execute function public.update_updated_at_column();

alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_thread_reads enable row level security;

drop policy if exists "Participants can view chat threads" on public.chat_threads;
create policy "Participants can view chat threads"
  on public.chat_threads for select
  using (buyer_id = auth.uid() or vendor_id = auth.uid());

drop policy if exists "Buyers can create chat threads" on public.chat_threads;
create policy "Buyers can create chat threads"
  on public.chat_threads for insert
  with check (
    buyer_id = auth.uid()
    and exists (
      select 1
      from public.shops s
      where s.id = shop_id
        and s.vendor_id = vendor_id
    )
  );

drop policy if exists "Participants can update chat threads" on public.chat_threads;
create policy "Participants can update chat threads"
  on public.chat_threads for update
  using (buyer_id = auth.uid() or vendor_id = auth.uid());

drop policy if exists "Participants can view chat messages" on public.chat_messages;
create policy "Participants can view chat messages"
  on public.chat_messages for select
  using (public.is_chat_thread_participant(thread_id));

drop policy if exists "Participants can insert chat messages" on public.chat_messages;
create policy "Participants can insert chat messages"
  on public.chat_messages for insert
  with check (
    sender_id = auth.uid()
    and public.is_chat_thread_participant(thread_id)
  );

drop policy if exists "Participants can view chat reads" on public.chat_thread_reads;
create policy "Participants can view chat reads"
  on public.chat_thread_reads for select
  using (public.is_chat_thread_participant(thread_id));

drop policy if exists "Participants can manage own chat reads" on public.chat_thread_reads;
create policy "Participants can manage own chat reads"
  on public.chat_thread_reads for insert
  with check (
    participant_id = auth.uid()
    and public.is_chat_thread_participant(thread_id)
  );

drop policy if exists "Participants can update own chat reads" on public.chat_thread_reads;
create policy "Participants can update own chat reads"
  on public.chat_thread_reads for update
  using (
    participant_id = auth.uid()
    and public.is_chat_thread_participant(thread_id)
  );

insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;

drop policy if exists "Chat participants can view attachments" on storage.objects;
create policy "Chat participants can view attachments"
  on storage.objects for select
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.chat_threads thread
      where thread.id::text = split_part(name, '/', 1)
        and (
          thread.buyer_id = auth.uid()
          or thread.vendor_id = auth.uid()
        )
    )
  );

drop policy if exists "Chat participants can upload attachments" on storage.objects;
create policy "Chat participants can upload attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.chat_threads thread
      where thread.id::text = split_part(name, '/', 1)
        and (
          thread.buyer_id = auth.uid()
          or thread.vendor_id = auth.uid()
        )
    )
  );

drop policy if exists "Chat participants can update attachments" on storage.objects;
create policy "Chat participants can update attachments"
  on storage.objects for update
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.chat_threads thread
      where thread.id::text = split_part(name, '/', 1)
        and (
          thread.buyer_id = auth.uid()
          or thread.vendor_id = auth.uid()
        )
    )
  );

drop policy if exists "Chat participants can delete attachments" on storage.objects;
create policy "Chat participants can delete attachments"
  on storage.objects for delete
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.chat_threads thread
      where thread.id::text = split_part(name, '/', 1)
        and (
          thread.buyer_id = auth.uid()
          or thread.vendor_id = auth.uid()
        )
    )
  );
