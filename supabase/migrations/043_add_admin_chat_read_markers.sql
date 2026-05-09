-- Shared admin-side read markers for admin <-> vendor chat threads.
-- Any admin opening a thread updates these fields, clearing the notification
-- for the whole admin team.

alter table public.chat_threads
  add column if not exists admin_last_read_message_id uuid
    references public.chat_messages(id) on delete set null,
  add column if not exists admin_last_read_at timestamptz;

create index if not exists idx_chat_threads_admin_unread
  on public.chat_threads (kind, admin_last_read_at, last_message_at)
  where kind = 'admin_vendor';
