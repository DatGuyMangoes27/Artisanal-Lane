create table if not exists stationery_requests (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references shops(id) on delete cascade not null,
  vendor_id uuid references profiles(id) on delete cascade not null,
  items jsonb not null default '[]'::jsonb,
  notes text,
  delivery_address text,
  status text not null default 'pending' check (status in ('pending','processing','shipped','delivered','cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table stationery_requests enable row level security;

create policy "Vendors can view own stationery requests" on stationery_requests
  for select using (auth.uid() = vendor_id);
create policy "Vendors can insert own stationery requests" on stationery_requests
  for insert with check (auth.uid() = vendor_id);

create trigger update_stationery_requests_updated_at
  before update on stationery_requests
  for each row execute function update_updated_at_column();
