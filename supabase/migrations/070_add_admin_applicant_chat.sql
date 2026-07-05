-- Admin <-> applicant chat threads.
--
-- Vendor applicants don't have shops yet, so the admin team needs a thread
-- kind that works without one: kind = 'admin_applicant', where buyer_id is
-- the applicant (they read it in their buyer inbox) and vendor_id is the
-- admin who opened the conversation.

alter table public.chat_threads
  alter column shop_id drop not null;

alter table public.chat_threads
  drop constraint if exists chat_threads_kind_check;

alter table public.chat_threads
  add constraint chat_threads_kind_check
  check (kind in ('buyer_vendor', 'admin_vendor', 'admin_applicant'));

-- Only applicant threads may omit the shop.
alter table public.chat_threads
  add constraint chat_threads_shop_id_required
  check (shop_id is not null or kind = 'admin_applicant');
