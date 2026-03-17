alter table shops
  add column if not exists is_spotlight boolean not null default false,
  add column if not exists spotlighted_at timestamptz;

create unique index if not exists idx_single_spotlight_shop
  on shops ((is_spotlight))
  where is_spotlight = true;
