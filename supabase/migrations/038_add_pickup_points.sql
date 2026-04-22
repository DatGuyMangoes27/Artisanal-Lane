-- Informational pickup-point catalogue. Not a live carrier integration —
-- this is a curated list buyers can search when they pick a delivery method
-- that uses lockers, kiosks, or partner stores. Vendors read the chosen
-- point from the order so they know where to drop the parcel off.

create table if not exists public.pickup_points (
  id uuid primary key default gen_random_uuid(),
  carrier text not null check (carrier in ('courier_guy', 'pargo', 'paxi')),
  -- 'locker' (Pudo), 'kiosk' (TCG in-store kiosk), 'branch' (TCG branch),
  -- 'store' (Pargo partner store / PAXI PEP / Tekkie Town / Shoe City).
  point_type text not null check (point_type in ('locker', 'kiosk', 'branch', 'store')),
  code text,              -- carrier-issued code, where known
  name text not null,
  address_line text not null,
  city text not null,
  province text not null check (province in (
    'Eastern Cape','Free State','Gauteng','KwaZulu-Natal','Limpopo',
    'Mpumalanga','Northern Cape','North West','Western Cape'
  )),
  postal_code text,
  latitude numeric(9,6),
  longitude numeric(9,6),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_pickup_points_carrier
  on public.pickup_points(carrier)
  where is_active = true;

create index if not exists idx_pickup_points_province
  on public.pickup_points(carrier, province)
  where is_active = true;

-- Trigram search across name / address / city / code for fast fuzzy lookup.
create extension if not exists pg_trgm;

create index if not exists idx_pickup_points_search
  on public.pickup_points
  using gin ((
    coalesce(name,'') || ' ' ||
    coalesce(address_line,'') || ' ' ||
    coalesce(city,'') || ' ' ||
    coalesce(code,'')
  ) gin_trgm_ops);

-- RLS: anyone can read active points; only service role / admins can write.
alter table public.pickup_points enable row level security;

drop policy if exists "Pickup points are public" on public.pickup_points;
create policy "Pickup points are public"
  on public.pickup_points
  for select
  using (is_active = true);

drop policy if exists "Admins manage pickup points" on public.pickup_points;
create policy "Admins manage pickup points"
  on public.pickup_points
  for all
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

-- Store the chosen pickup point snapshot on the order so it survives
-- future edits or removals of the catalogue row.
alter table public.orders
  add column if not exists pickup_point jsonb;

comment on column public.orders.pickup_point is
  'Snapshot of the pickup point the buyer selected at checkout: '
  '{carrier, point_type, code, name, address_line, city, province, postal_code}.';

create trigger pickup_points_updated_at
  before update on public.pickup_points
  for each row
  execute function public.update_updated_at_column();
