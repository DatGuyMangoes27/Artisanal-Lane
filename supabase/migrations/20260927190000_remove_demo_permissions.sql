-- Remove legacy demo-wide access. Existing owner-scoped policies remain the
-- source of access. Checkout, escrow, disputes, approvals and admin work run
-- through the service role and are unaffected. No rows are changed.
-- Apply after 20260925092917_harden_profile_writes.sql.

drop policy if exists demo_profiles_all on public.profiles;
drop policy if exists demo_shops_all on public.shops;
drop policy if exists demo_vendor_applications_all on public.vendor_applications;
drop policy if exists demo_orders_all on public.orders;
drop policy if exists demo_order_items_all on public.order_items;
drop policy if exists demo_escrow_all on public.escrow_transactions;
drop policy if exists demo_carts_all on public.carts;
drop policy if exists demo_cart_items_all on public.cart_items;
drop policy if exists demo_favourites_all on public.favourites;
drop policy if exists demo_disputes_all on public.disputes;
drop policy if exists demo_shop_follows_all on public.shop_follows;
drop policy if exists demo_shop_posts_select on public.shop_posts;

-- Shops are created by trusted approval flows only; owners keep sight of their
-- own shop while it is inactive.
drop policy if exists vendor_insert_own_shop on public.shops;
create policy shops_owner_select on public.shops
for select to authenticated using (vendor_id = (select auth.uid()));

create function public.guard_shop_privileged_fields() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if current_user in ('postgres','service_role','supabase_admin') then return new; end if;
  if new.id is distinct from old.id
    or new.vendor_id is distinct from old.vendor_id
    or new.is_active is distinct from old.is_active
    or new.is_spotlight is distinct from old.is_spotlight
    or new.spotlighted_at is distinct from old.spotlighted_at
    or new.created_at is distinct from old.created_at then
    raise exception 'Shop status and ownership changes require a trusted server operation' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_shop_privileged_fields() from public,anon,authenticated;
create trigger guard_shop_privileged_fields before update on public.shops
for each row execute function public.guard_shop_privileged_fields();

-- Order status changes go through mark-order-shipped and other server functions.
drop policy if exists vendor_update_shop_orders on public.orders;

-- Disputes are opened through the open-dispute function, which checks the order.
drop policy if exists "Users can create disputes" on public.disputes;

-- Owners and admins keep draft visibility once the demo read is gone. The
-- restrictive creator_posts_read_guard still applies.
create policy shop_posts_owner_select on public.shop_posts
for select to authenticated using (
  (select public.current_user_is_admin()) or exists (
    select 1 from public.shops s
    where s.id = shop_posts.shop_id and s.vendor_id = (select auth.uid())
  )
);

-- Applicants can only submit their own pending, unreviewed application.
create policy vendor_applications_insert_pending_guard on public.vendor_applications
as restrictive for insert to anon,authenticated with check (
  user_id = (select auth.uid()) and status = 'pending'
  and reviewed_by is null and reviewed_at is null
  and superseded_by_application_id is null and superseded_at is null
);

-- Invite codes are not read or written by user-scoped clients.
drop policy if exists "Invite codes viewable by admin" on public.invite_codes;
drop policy if exists users_select_invite_codes on public.invite_codes;
drop policy if exists users_update_invite_codes on public.invite_codes;
create policy invite_codes_admin_select on public.invite_codes
for select to authenticated using ((select public.current_user_is_admin()));
