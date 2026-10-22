-- Shops without an active Artisan Lane subscription are not shown anywhere
-- on the public marketplace (apps and website), and cannot publish feed
-- posts. Approval gives an artisan access to subscribe, not free exposure.
--
-- "Active" is public.vendor_subscription_is_active (5-day payment grace,
-- cancelled-but-paid-through, past_due grace). Unsubscribed shops stay in
-- the database and the admin backend as leads, and keep working for:
--   * the artisan's own vendor screens (shops_owner_select,
--     vendor_select_own_products, owner post/story policies);
--   * admins (new admin read policies; the web admin uses the service role);
--   * buyers who already ordered from / chatted with the shop, so order
--     history, reviews and the inbox still resolve shop and product names.
--
-- How it works
--   shops.is_publicly_listed = is_active and the vendor's subscription is
--   active. A BEFORE trigger on shops always recomputes it (clients can't set
--   it), a trigger on vendor_subscriptions refreshes it the moment PayFast /
--   admin changes a subscription, and a pg_cron job every 10 minutes catches
--   subscriptions that lapse just by time passing (grace/period end). Time
--   passing can only make a shop unlisted, never listed, so the job is the
--   only path that needs a clock.
--
--   Public read policies on shops/products/shop_posts/shop_stories require
--   is_publicly_listed, so every client is covered server-side. Clients also
--   filter on the column in public lists, so a buyer who can read an
--   unlisted shop only because of an order/chat doesn't see it in the
--   directory, grids or search.
--
--   Publishing a feed post (insert as published, or editing the content of a
--   published post) requires an active subscription, enforced by a trigger
--   so it also covers the website's service-role vendor actions.

-- ── Listing flag ─────────────────────────────────────────────────────────
alter table public.shops
  add column if not exists is_publicly_listed boolean not null default false;

comment on column public.shops.is_publicly_listed is
  'Maintained by triggers + cron: is_active and vendor_subscription_is_active(vendor_id). Public marketplace visibility.';

create or replace function public.shop_should_be_publicly_listed(
  shop_is_active boolean,
  shop_vendor_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(shop_is_active, false)
    and shop_vendor_id is not null
    and public.vendor_subscription_is_active(shop_vendor_id);
$$;

create or replace function public.set_shop_public_listing()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.is_publicly_listed := public.shop_should_be_publicly_listed(new.is_active, new.vendor_id);
  return new;
end;
$$;

drop trigger if exists set_shop_public_listing on public.shops;
create trigger set_shop_public_listing
  before insert or update on public.shops
  for each row execute function public.set_shop_public_listing();

-- Recomputes the flag for one vendor's shops (or every shop when null).
-- Only touches rows whose value actually changes.
create or replace function public.refresh_shop_public_listings(target_vendor_id uuid default null)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  changed integer;
begin
  update public.shops s
     set is_publicly_listed = public.shop_should_be_publicly_listed(s.is_active, s.vendor_id)
   where (target_vendor_id is null or s.vendor_id = target_vendor_id)
     and s.is_publicly_listed is distinct from
         public.shop_should_be_publicly_listed(s.is_active, s.vendor_id);
  get diagnostics changed = row_count;
  return changed;
end;
$$;

create or replace function public.sync_shop_public_listing_from_subscription()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform public.refresh_shop_public_listings(old.vendor_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.vendor_id is not null then
    perform public.refresh_shop_public_listings(new.vendor_id);
  end if;
  return null;
end;
$$;

drop trigger if exists sync_shop_public_listing on public.vendor_subscriptions;
create trigger sync_shop_public_listing
  after insert or update or delete on public.vendor_subscriptions
  for each row execute function public.sync_shop_public_listing_from_subscription();

revoke all on function public.shop_should_be_publicly_listed(boolean, uuid) from public, anon, authenticated;
revoke all on function public.set_shop_public_listing() from public, anon, authenticated;
revoke all on function public.refresh_shop_public_listings(uuid) from public, anon, authenticated;
revoke all on function public.sync_shop_public_listing_from_subscription() from public, anon, authenticated;
grant execute on function public.refresh_shop_public_listings(uuid) to service_role;

-- Backfill.
select public.refresh_shop_public_listings();

-- Time-based expiry (grace / paid-through end). Skipped where pg_cron isn't
-- installed (local test databases).
do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'refresh-shop-public-listings';
    perform cron.schedule(
      'refresh-shop-public-listings',
      '*/10 * * * *',
      'select public.refresh_shop_public_listings();'
    );
  end if;
end;
$cron$;

-- ── Related-party helpers (SECURITY DEFINER so shops/products policies can
-- look at orders/chats without recursing through their RLS) ───────────────
create or replace function public.current_user_related_shop_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.shop_id from public.orders o
   where o.buyer_id = auth.uid() and o.shop_id is not null
  union
  select t.shop_id from public.chat_threads t
   where t.buyer_id = auth.uid() and t.shop_id is not null;
$$;

create or replace function public.current_user_ordered_product_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select distinct oi.product_id
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
   where o.buyer_id = auth.uid() and oi.product_id is not null;
$$;

revoke all on function public.current_user_related_shop_ids() from public, anon;
revoke all on function public.current_user_ordered_product_ids() from public, anon;
grant execute on function public.current_user_related_shop_ids() to authenticated;
grant execute on function public.current_user_ordered_product_ids() to authenticated;

-- ── shops ────────────────────────────────────────────────────────────────
drop policy if exists "Active shops are viewable by everyone" on public.shops;
drop policy if exists shops_public_listed_read on public.shops;
create policy shops_public_listed_read on public.shops
  for select to anon, authenticated
  using (is_publicly_listed);

drop policy if exists shops_admin_read on public.shops;
create policy shops_admin_read on public.shops
  for select to authenticated
  using ((select public.current_user_is_admin()));

drop policy if exists shops_related_buyer_read on public.shops;
create policy shops_related_buyer_read on public.shops
  for select to authenticated
  using (id in (select public.current_user_related_shop_ids()));

-- ── products ─────────────────────────────────────────────────────────────
drop policy if exists "Published products viewable by everyone" on public.products;
drop policy if exists products_public_listed_read on public.products;
create policy products_public_listed_read on public.products
  for select to anon, authenticated
  using (
    is_published = true
    and archived_at is null
    and exists (
      select 1 from public.shops s
       where s.id = products.shop_id and s.is_publicly_listed
    )
  );

drop policy if exists products_admin_read on public.products;
create policy products_admin_read on public.products
  for select to authenticated
  using ((select public.current_user_is_admin()));

drop policy if exists products_ordered_by_buyer_read on public.products;
create policy products_ordered_by_buyer_read on public.products
  for select to authenticated
  using (id in (select public.current_user_ordered_product_ids()));

-- ── shop_posts: read guard ───────────────────────────────────────────────
drop policy if exists creator_posts_read_guard on public.shop_posts;
create policy creator_posts_read_guard on public.shop_posts
  as restrictive for select to anon, authenticated
  using (
    (select public.current_user_is_admin())
    or exists (
      select 1 from public.shops s
       where s.id = shop_id
         and (
           s.vendor_id = (select auth.uid())
           or (is_published and s.is_publicly_listed and not s.is_offline)
         )
    )
  );

-- ── shop_stories: live stories only from listed shops ────────────────────
drop policy if exists stories_live_read on public.shop_stories;
create policy stories_live_read on public.shop_stories
  for select to anon, authenticated
  using (
    expires_at > now()
    and exists (
      select 1 from public.shops s
       where s.id = shop_id
         and ((s.is_publicly_listed and not s.is_offline) or s.vendor_id = (select auth.uid()))
    )
  );

-- ── shop_posts: publishing needs an active subscription ──────────────────
create or replace function public.shop_owner_can_publish_posts(target_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shops s
     where s.id = target_shop_id
       and public.vendor_subscription_is_active(s.vendor_id)
  );
$$;

revoke all on function public.shop_owner_can_publish_posts(uuid) from public, anon;
grant execute on function public.shop_owner_can_publish_posts(uuid) to authenticated, service_role;

create or replace function public.guard_unsubscribed_post_publishing()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Drafts are fine; unpublishing is fine.
  if not coalesce(new.is_published, false) then
    return new;
  end if;

  -- Settings/moderation changes to an already-published post (comments,
  -- like counts, removal) don't republish anything.
  if tg_op = 'UPDATE'
     and coalesce(old.is_published, false)
     and new.shop_id is not distinct from old.shop_id
     and new.caption is not distinct from old.caption
     and new.media_urls is not distinct from old.media_urls
     and new.product_ids is not distinct from old.product_ids
     and new.step_captions is not distinct from old.step_captions
     and new.format is not distinct from old.format
     and new.scheduled_for is not distinct from old.scheduled_for then
    return new;
  end if;

  -- Database maintenance and Artisan Lane admins.
  if current_user in ('postgres', 'supabase_admin') or public.current_user_is_admin() then
    return new;
  end if;

  if public.shop_owner_can_publish_posts(new.shop_id) then
    return new;
  end if;

  raise exception 'Subscribe to post to the feed. Feed posts are part of your Artisan Lane subscription.'
    using errcode = 'P0001', hint = 'subscription_required_to_post';
end;
$$;

drop trigger if exists guard_unsubscribed_post_publishing on public.shop_posts;
create trigger guard_unsubscribed_post_publishing
  before insert or update on public.shop_posts
  for each row execute function public.guard_unsubscribed_post_publishing();
