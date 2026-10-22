-- The app's live screens (chat, inbox, notifications, order status, payouts,
-- subscription, applications, favourites, disputes) use Supabase realtime
-- streams, but the supabase_realtime publication had no tables, so those
-- screens only loaded once: a sent chat message never appeared until the
-- screen was reopened, and unread badges never cleared.
--
-- Realtime applies each table's RLS to every subscriber, so people only
-- receive changes to rows they can already read.

do $$
declare
  t text;
begin
  foreach t in array array[
    'chat_messages',
    'chat_threads',
    'chat_thread_reads',
    'notifications',
    'orders',
    'favourites',
    'dispute_conversations',
    'dispute_conversation_messages',
    'stationery_requests',
    'trending_searches',
    'vendor_applications',
    'vendor_payout_profiles',
    'vendor_subscriptions'
  ] loop
    if to_regclass('public.' || t) is not null and not exists (
      select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end;
$$;
