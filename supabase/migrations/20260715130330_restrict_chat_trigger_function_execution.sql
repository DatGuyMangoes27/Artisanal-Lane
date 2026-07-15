-- Trigger functions do not need to be callable as Data API RPCs.
-- Keep guard_chat_thread as SECURITY DEFINER so authenticated inserts can read
-- auth.users, but prevent direct execution by public API roles.

revoke execute on function public.guard_chat_thread() from public, anon, authenticated;
revoke execute on function public.set_chat_thread_vendor_id() from public, anon, authenticated;
