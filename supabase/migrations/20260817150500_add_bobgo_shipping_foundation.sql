-- Bob Go door-to-door shipping foundation.
-- This migration is intentionally additive: existing delivery methods remain unchanged.

alter table public.products
  add column if not exists shipping_weight_kg numeric(10,3),
  add column if not exists shipping_length_cm numeric(10,2),
  add column if not exists shipping_width_cm numeric(10,2),
  add column if not exists shipping_height_cm numeric(10,2);

alter table public.products
  drop constraint if exists products_shipping_measurements_positive;

alter table public.products
  add constraint products_shipping_measurements_positive
  check (
    (shipping_weight_kg is null or shipping_weight_kg > 0)
    and (shipping_length_cm is null or shipping_length_cm > 0)
    and (shipping_width_cm is null or shipping_width_cm > 0)
    and (shipping_height_cm is null or shipping_height_cm > 0)
  );

-- Collection addresses are private operational data. Keep them out of public.shops,
-- which is readable by buyers for storefront rendering.
create table if not exists public.shop_fulfillment_profiles (
  shop_id uuid primary key references public.shops(id) on delete cascade,
  contact_full_name text not null,
  contact_email text not null,
  contact_phone text not null,
  company text,
  street_address text not null,
  local_area text not null,
  city text not null,
  province text not null,
  postal_code text not null,
  country_code text not null default 'ZA' check (country_code = 'ZA'),
  bobgo_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.shop_fulfillment_profiles enable row level security;

revoke all on table public.shop_fulfillment_profiles from anon;
grant select, insert, update on table public.shop_fulfillment_profiles to authenticated;

drop policy if exists "Vendors can read own fulfillment profile"
  on public.shop_fulfillment_profiles;
create policy "Vendors can read own fulfillment profile"
  on public.shop_fulfillment_profiles for select
  to authenticated
  using (
    exists (
      select 1
      from public.shops
      where shops.id = shop_fulfillment_profiles.shop_id
        and shops.vendor_id = (select auth.uid())
    )
  );

drop policy if exists "Vendors can create own fulfillment profile"
  on public.shop_fulfillment_profiles;
create policy "Vendors can create own fulfillment profile"
  on public.shop_fulfillment_profiles for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.shops
      where shops.id = shop_fulfillment_profiles.shop_id
        and shops.vendor_id = (select auth.uid())
    )
  );

drop policy if exists "Vendors can update own fulfillment profile"
  on public.shop_fulfillment_profiles;
create policy "Vendors can update own fulfillment profile"
  on public.shop_fulfillment_profiles for update
  to authenticated
  using (
    exists (
      select 1
      from public.shops
      where shops.id = shop_fulfillment_profiles.shop_id
        and shops.vendor_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.shops
      where shops.id = shop_fulfillment_profiles.shop_id
        and shops.vendor_id = (select auth.uid())
    )
  );

create table if not exists public.bobgo_shipping_quotes (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  rate_request_id bigint not null,
  rates jsonb not null default '[]'::jsonb,
  items_snapshot jsonb not null default '[]'::jsonb,
  request_snapshot jsonb not null,
  expires_at timestamptz not null default (now() + interval '20 minutes'),
  created_at timestamptz not null default now()
);

alter table public.bobgo_shipping_quotes enable row level security;
revoke all on table public.bobgo_shipping_quotes from anon, authenticated;

create index if not exists bobgo_shipping_quotes_buyer_expiry_idx
  on public.bobgo_shipping_quotes (buyer_id, expires_at desc);

alter table public.orders
  add column if not exists bobgo_quote_id uuid references public.bobgo_shipping_quotes(id),
  add column if not exists bobgo_rate_request_id bigint,
  add column if not exists bobgo_rate_response_id bigint,
  add column if not exists bobgo_provider_slug text,
  add column if not exists bobgo_service_level_code text,
  add column if not exists bobgo_shipment_id text,
  add column if not exists bobgo_booking_state text not null default 'not_requested',
  add column if not exists bobgo_booking_error text,
  add column if not exists bobgo_status text,
  add column if not exists bobgo_charged_amount numeric(12,2),
  add column if not exists bobgo_tracking_url text,
  add column if not exists tradesafe_shipping_party_id text,
  add column if not exists tradesafe_shipping_fee numeric(12,2) not null default 0;

alter table public.orders
  drop constraint if exists orders_bobgo_booking_state_check;

alter table public.orders
  add constraint orders_bobgo_booking_state_check
  check (bobgo_booking_state in ('not_requested', 'booking', 'booked', 'failed'));

alter table public.orders
  drop constraint if exists orders_shipping_method_check;

alter table public.orders
  add constraint orders_shipping_method_check
  check (
    shipping_method in (
      'courier_guy',
      'courier_guy_door_to_door',
      'bobgo_door_to_door',
      'pargo',
      'market_pickup'
    )
  );
