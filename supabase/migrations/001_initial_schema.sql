-- ============================================================
-- Artisanal Lane - Initial Database Schema
-- ============================================================

-- 1. Profiles (extends auth.users)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'buyer' check (role in ('buyer','vendor','admin')),
  display_name text,
  email text,
  avatar_url text,
  phone text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. Categories
create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  icon_url text,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- 3. Invite Codes
create table if not exists invite_codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_by uuid references profiles(id),
  used_by uuid references profiles(id),
  is_used boolean default false,
  used_at timestamptz,
  created_at timestamptz default now()
);

-- 4. Vendor Applications
create table if not exists vendor_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  business_name text not null,
  motivation text,
  portfolio_url text,
  location text,
  status text default 'pending' check (status in ('pending','approved','rejected')),
  invite_code text references invite_codes(code),
  reviewed_by uuid references profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 5. Shops
create table if not exists shops (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid unique references profiles(id) on delete cascade,
  name text not null,
  slug text unique not null,
  bio text,
  brand_story text,
  cover_image_url text,
  logo_url text,
  location text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 6. Products
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references shops(id) on delete cascade,
  category_id uuid references categories(id),
  title text not null,
  description text,
  price numeric(10,2) not null,
  compare_at_price numeric(10,2),
  stock_qty int default 0,
  images jsonb default '[]',
  is_published boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 7. Favourites
create table if not exists favourites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  created_at timestamptz default now(),
  unique(user_id, product_id)
);

-- 8. Carts
create table if not exists carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 9. Cart Items
create table if not exists cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid references carts(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  quantity int default 1 check (quantity > 0),
  created_at timestamptz default now(),
  unique(cart_id, product_id)
);

-- 10. Orders
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid references profiles(id),
  shop_id uuid references shops(id),
  status text default 'pending' check (status in ('pending','paid','shipped','delivered','completed','disputed','cancelled')),
  total numeric(10,2) not null,
  shipping_cost numeric(10,2) default 0,
  shipping_method text check (shipping_method in ('courier_guy','pargo','paxi','market_pickup')),
  shipping_address jsonb,
  tracking_number text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 11. Order Items
create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  product_id uuid references products(id),
  quantity int not null,
  unit_price numeric(10,2) not null,
  created_at timestamptz default now()
);

-- 12. Escrow Transactions
create table if not exists escrow_transactions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  payfast_payment_id text,
  amount numeric(10,2) not null,
  platform_fee numeric(10,2) default 0,
  status text default 'held' check (status in ('held','released','refunded')),
  released_at timestamptz,
  created_at timestamptz default now()
);

-- 13. Disputes
create table if not exists disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  raised_by uuid references profiles(id),
  reason text not null,
  status text default 'open' check (status in ('open','investigating','resolved','closed')),
  resolution text,
  resolved_by uuid references profiles(id),
  resolved_at timestamptz,
  created_at timestamptz default now()
);

-- ============================================================
-- Indexes
-- ============================================================
create index if not exists idx_products_shop_id on products(shop_id);
create index if not exists idx_products_category_id on products(category_id);
create index if not exists idx_products_is_published on products(is_published);
create index if not exists idx_products_created_at on products(created_at desc);
create index if not exists idx_favourites_user_id on favourites(user_id);
create index if not exists idx_cart_items_cart_id on cart_items(cart_id);
create index if not exists idx_orders_buyer_id on orders(buyer_id);
create index if not exists idx_orders_shop_id on orders(shop_id);
create index if not exists idx_orders_status on orders(status);
create index if not exists idx_order_items_order_id on order_items(order_id);
create index if not exists idx_shops_is_active on shops(is_active);

-- ============================================================
-- Row Level Security Policies
-- ============================================================

-- Enable RLS on all tables
alter table profiles enable row level security;
alter table categories enable row level security;
alter table invite_codes enable row level security;
alter table vendor_applications enable row level security;
alter table shops enable row level security;
alter table products enable row level security;
alter table favourites enable row level security;
alter table carts enable row level security;
alter table cart_items enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table escrow_transactions enable row level security;
alter table disputes enable row level security;

-- Profiles: users can read all, update own
create policy "Profiles are viewable by everyone" on profiles for select using (true);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on profiles for insert with check (auth.uid() = id);

-- Categories: public read
create policy "Categories are viewable by everyone" on categories for select using (true);

-- Invite Codes: admins can manage, users can view own
create policy "Invite codes viewable by admin" on invite_codes for select using (true);

-- Vendor Applications: users can view own, admins can view all
create policy "Users can view own applications" on vendor_applications for select using (auth.uid() = user_id);
create policy "Users can insert applications" on vendor_applications for insert with check (auth.uid() = user_id);

-- Shops: public read for active shops
create policy "Active shops are viewable by everyone" on shops for select using (is_active = true);
create policy "Vendors can update own shop" on shops for update using (auth.uid() = vendor_id);

-- Products: public read for published products
create policy "Published products viewable by everyone" on products for select using (is_published = true);

-- Favourites: users can manage own
create policy "Users can view own favourites" on favourites for select using (auth.uid() = user_id);
create policy "Users can insert own favourites" on favourites for insert with check (auth.uid() = user_id);
create policy "Users can delete own favourites" on favourites for delete using (auth.uid() = user_id);

-- Carts: users can manage own
create policy "Users can view own cart" on carts for select using (auth.uid() = user_id);
create policy "Users can create own cart" on carts for insert with check (auth.uid() = user_id);
create policy "Users can update own cart" on carts for update using (auth.uid() = user_id);

-- Cart Items: users can manage items in own cart
create policy "Users can view own cart items" on cart_items for select
  using (cart_id in (select id from carts where user_id = auth.uid()));
create policy "Users can insert cart items" on cart_items for insert
  with check (cart_id in (select id from carts where user_id = auth.uid()));
create policy "Users can update cart items" on cart_items for update
  using (cart_id in (select id from carts where user_id = auth.uid()));
create policy "Users can delete cart items" on cart_items for delete
  using (cart_id in (select id from carts where user_id = auth.uid()));

-- Orders: users can view own orders
create policy "Buyers can view own orders" on orders for select using (auth.uid() = buyer_id);

-- Order Items: users can view items from own orders
create policy "Users can view own order items" on order_items for select
  using (order_id in (select id from orders where buyer_id = auth.uid()));

-- Escrow: users can view escrow for own orders
create policy "Users can view own escrow" on escrow_transactions for select
  using (order_id in (select id from orders where buyer_id = auth.uid()));

-- Disputes: users can manage own disputes
create policy "Users can view own disputes" on disputes for select using (auth.uid() = raised_by);
create policy "Users can create disputes" on disputes for insert with check (auth.uid() = raised_by);

-- ============================================================
-- Updated_at trigger function
-- ============================================================
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger update_profiles_updated_at before update on profiles
  for each row execute function update_updated_at_column();
create trigger update_shops_updated_at before update on shops
  for each row execute function update_updated_at_column();
create trigger update_products_updated_at before update on products
  for each row execute function update_updated_at_column();
create trigger update_carts_updated_at before update on carts
  for each row execute function update_updated_at_column();
create trigger update_orders_updated_at before update on orders
  for each row execute function update_updated_at_column();
create trigger update_vendor_applications_updated_at before update on vendor_applications
  for each row execute function update_updated_at_column();

-- ============================================================
-- Storage Buckets (run via Supabase dashboard or API)
-- ============================================================
-- insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true);
-- insert into storage.buckets (id, name, public) values ('shop-branding', 'shop-branding', true);
-- insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);
