alter table orders
  add column if not exists shipped_at timestamptz,
  add column if not exists received_at timestamptz;

alter table products
  add column if not exists is_featured boolean not null default false,
  add column if not exists featured_at timestamptz;

create index if not exists idx_products_is_featured_featured_at
  on products(is_featured, featured_at desc)
  where is_featured = true;
