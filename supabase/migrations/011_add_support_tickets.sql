create table if not exists support_tickets (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references shops(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade not null,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table support_tickets enable row level security;

create policy "Users can view own support tickets" on support_tickets
  for select using (auth.uid() = user_id);
create policy "Users can insert own support tickets" on support_tickets
  for insert with check (auth.uid() = user_id);

create trigger update_support_tickets_updated_at
  before update on support_tickets
  for each row execute function update_updated_at_column();
