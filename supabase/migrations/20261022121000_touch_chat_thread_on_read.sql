-- Unread chat badges didn't clear after opening a conversation: the app's
-- inbox streams chat_threads, but marking read only writes chat_thread_reads,
-- so the stream never re-emitted and the badge kept the old unread count.
-- Touch the thread when its read state moves forward, which makes every
-- client (including already-installed app versions) recompute unread counts.

create or replace function public.touch_chat_thread_on_read()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT'
     or new.last_read_at is distinct from old.last_read_at
     or new.last_read_message_id is distinct from old.last_read_message_id then
    update public.chat_threads
       set updated_at = now()
     where id = new.thread_id;
  end if;
  return null;
end;
$$;

revoke all on function public.touch_chat_thread_on_read() from public, anon, authenticated;

drop trigger if exists touch_chat_thread_on_read_trigger on public.chat_thread_reads;
create trigger touch_chat_thread_on_read_trigger
  after insert or update on public.chat_thread_reads
  for each row execute function public.touch_chat_thread_on_read();
