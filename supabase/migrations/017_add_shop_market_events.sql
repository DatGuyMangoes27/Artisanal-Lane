-- Add structured upcoming market events for artisan shop profiles
create table if not exists public.shop_market_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  market_name text not null,
  location text not null,
  event_date date not null,
  time_label text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_shop_market_events_shop_date
  on public.shop_market_events(shop_id, event_date asc);

create index if not exists idx_shop_market_events_active_date
  on public.shop_market_events(is_active, event_date asc);

alter table public.shop_market_events enable row level security;

create policy "Active market events are publicly readable"
  on public.shop_market_events for select
  using (is_active = true);

create policy "Vendors can view own market events"
  on public.shop_market_events for select
  using (
    shop_id in (
      select id from public.shops where vendor_id = auth.uid()
    )
  );

create policy "Vendors can insert own market events"
  on public.shop_market_events for insert
  with check (
    shop_id in (
      select id from public.shops where vendor_id = auth.uid()
    )
  );

create policy "Vendors can update own market events"
  on public.shop_market_events for update
  using (
    shop_id in (
      select id from public.shops where vendor_id = auth.uid()
    )
  );

create policy "Vendors can delete own market events"
  on public.shop_market_events for delete
  using (
    shop_id in (
      select id from public.shops where vendor_id = auth.uid()
    )
  );

create trigger set_shop_market_events_updated_at
  before update on public.shop_market_events
  for each row execute function update_updated_at_column();
