-- ============================================================
-- Dispute-specific conversations
-- ============================================================

create table if not exists public.dispute_conversations (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null unique references public.disputes(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  last_message_preview text,
  last_message_type text not null default 'text'
    check (last_message_type in ('text', 'attachment', 'text_with_attachment')),
  last_message_sender_id uuid references public.profiles(id) on delete set null,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_dispute_conversations_dispute_id
  on public.dispute_conversations (dispute_id);

create index if not exists idx_dispute_conversations_order_id
  on public.dispute_conversations (order_id);

create table if not exists public.dispute_conversation_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.dispute_conversations(id) on delete cascade,
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

create index if not exists idx_dispute_conversation_messages_conversation_id
  on public.dispute_conversation_messages (conversation_id, created_at asc);

create index if not exists idx_dispute_conversation_messages_sender_id
  on public.dispute_conversation_messages (sender_id);

create table if not exists public.dispute_conversation_participants (
  conversation_id uuid not null references public.dispute_conversations(id) on delete cascade,
  participant_id uuid not null references public.profiles(id) on delete cascade,
  role_in_case text not null check (role_in_case in ('buyer', 'seller', 'admin')),
  last_read_message_id uuid references public.dispute_conversation_messages(id) on delete set null,
  last_read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, participant_id)
);

create index if not exists idx_dispute_conversation_participants_participant_id
  on public.dispute_conversation_participants (participant_id, updated_at desc);

create or replace function public.is_dispute_conversation_participant(conversation_uuid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.dispute_conversation_participants participant
    where participant.conversation_id = conversation_uuid
      and participant.participant_id = auth.uid()
  );
$$;

create or replace function public.touch_dispute_conversation_on_message()
returns trigger
language plpgsql
as $$
begin
  update public.dispute_conversations
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
  where id = new.conversation_id;

  return new;
end;
$$;

drop trigger if exists touch_dispute_conversation_on_message_trigger on public.dispute_conversation_messages;
create trigger touch_dispute_conversation_on_message_trigger
  after insert on public.dispute_conversation_messages
  for each row execute function public.touch_dispute_conversation_on_message();

drop trigger if exists update_dispute_conversations_updated_at on public.dispute_conversations;
create trigger update_dispute_conversations_updated_at
  before update on public.dispute_conversations
  for each row execute function public.update_updated_at_column();

drop trigger if exists update_dispute_conversation_participants_updated_at on public.dispute_conversation_participants;
create trigger update_dispute_conversation_participants_updated_at
  before update on public.dispute_conversation_participants
  for each row execute function public.update_updated_at_column();

alter table public.dispute_conversations enable row level security;
alter table public.dispute_conversation_messages enable row level security;
alter table public.dispute_conversation_participants enable row level security;

drop policy if exists "Dispute participants can view conversations" on public.dispute_conversations;
create policy "Dispute participants can view conversations"
  on public.dispute_conversations for select
  using (public.is_dispute_conversation_participant(id));

drop policy if exists "Dispute participants can view messages" on public.dispute_conversation_messages;
create policy "Dispute participants can view messages"
  on public.dispute_conversation_messages for select
  using (public.is_dispute_conversation_participant(conversation_id));

drop policy if exists "Dispute participants can insert messages" on public.dispute_conversation_messages;
create policy "Dispute participants can insert messages"
  on public.dispute_conversation_messages for insert
  with check (
    sender_id = auth.uid()
    and public.is_dispute_conversation_participant(conversation_id)
  );

drop policy if exists "Dispute participants can view participant state" on public.dispute_conversation_participants;
create policy "Dispute participants can view participant state"
  on public.dispute_conversation_participants for select
  using (public.is_dispute_conversation_participant(conversation_id));

drop policy if exists "Dispute participants can update own read state" on public.dispute_conversation_participants;
create policy "Dispute participants can update own read state"
  on public.dispute_conversation_participants for update
  using (
    participant_id = auth.uid()
    and public.is_dispute_conversation_participant(conversation_id)
  );

drop policy if exists "Users can view own disputes" on public.disputes;
create policy "Dispute participants can view disputes"
  on public.disputes for select
  using (
    auth.uid() = raised_by
    or exists (
      select 1
      from public.orders ord
      join public.shops shop on shop.id = ord.shop_id
      where ord.id = disputes.order_id
        and shop.vendor_id = auth.uid()
    )
    or exists (
      select 1
      from public.profiles profile
      where profile.id = auth.uid()
        and profile.role = 'admin'
    )
  );

insert into storage.buckets (id, name, public)
values ('dispute-attachments', 'dispute-attachments', false)
on conflict (id) do nothing;

drop policy if exists "Dispute participants can view attachments" on storage.objects;
create policy "Dispute participants can view attachments"
  on storage.objects for select
  using (
    bucket_id = 'dispute-attachments'
    and exists (
      select 1
      from public.dispute_conversation_participants participant
      where participant.conversation_id::text = split_part(name, '/', 1)
        and participant.participant_id = auth.uid()
    )
  );

drop policy if exists "Dispute participants can upload attachments" on storage.objects;
create policy "Dispute participants can upload attachments"
  on storage.objects for insert
  with check (
    bucket_id = 'dispute-attachments'
    and exists (
      select 1
      from public.dispute_conversation_participants participant
      where participant.conversation_id::text = split_part(name, '/', 1)
        and participant.participant_id = auth.uid()
    )
  );

drop policy if exists "Dispute participants can update attachments" on storage.objects;
drop policy if exists "Dispute participants can delete attachments" on storage.objects;
