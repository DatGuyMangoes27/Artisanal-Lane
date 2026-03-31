-- ============================================================
-- Shop and product reviews
-- ============================================================

create table if not exists public.shop_reviews (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  rating int not null check (rating between 1 and 5),
  review_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, buyer_id)
);

create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  order_item_id uuid references public.order_items(id) on delete set null,
  rating int not null check (rating between 1 and 5),
  review_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, buyer_id)
);

create index if not exists idx_shop_reviews_shop_id
  on public.shop_reviews (shop_id, created_at desc);

create index if not exists idx_shop_reviews_buyer_id
  on public.shop_reviews (buyer_id, created_at desc);

create index if not exists idx_product_reviews_product_id
  on public.product_reviews (product_id, created_at desc);

create index if not exists idx_product_reviews_shop_id
  on public.product_reviews (shop_id, created_at desc);

create index if not exists idx_product_reviews_buyer_id
  on public.product_reviews (buyer_id, created_at desc);

create or replace function public.buyer_can_review_shop(target_shop_id uuid)
returns boolean
language sql
stable
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.orders o
      where o.buyer_id = auth.uid()
        and o.shop_id = target_shop_id
        and o.status in ('delivered', 'completed')
    );
$$;

create or replace function public.buyer_can_review_product(target_product_id uuid)
returns boolean
language sql
stable
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.product_id = target_product_id
        and o.buyer_id = auth.uid()
        and o.status in ('delivered', 'completed')
    );
$$;

create or replace function public.set_product_review_shop_id()
returns trigger
language plpgsql
as $$
declare
  resolved_shop_id uuid;
begin
  select p.shop_id
  into resolved_shop_id
  from public.products p
  where p.id = new.product_id;

  if resolved_shop_id is null then
    raise exception 'Product not found for review';
  end if;

  new.shop_id := resolved_shop_id;
  return new;
end;
$$;

drop trigger if exists update_shop_reviews_updated_at on public.shop_reviews;
create trigger update_shop_reviews_updated_at
  before update on public.shop_reviews
  for each row execute function public.update_updated_at_column();

drop trigger if exists update_product_reviews_updated_at on public.product_reviews;
create trigger update_product_reviews_updated_at
  before update on public.product_reviews
  for each row execute function public.update_updated_at_column();

drop trigger if exists set_product_review_shop_id_trigger on public.product_reviews;
create trigger set_product_review_shop_id_trigger
  before insert or update on public.product_reviews
  for each row execute function public.set_product_review_shop_id();

alter table public.shop_reviews enable row level security;
alter table public.product_reviews enable row level security;

drop policy if exists "Shop reviews are publicly readable" on public.shop_reviews;
create policy "Shop reviews are publicly readable"
  on public.shop_reviews for select
  using (true);

drop policy if exists "Eligible buyers can insert shop reviews" on public.shop_reviews;
create policy "Eligible buyers can insert shop reviews"
  on public.shop_reviews for insert
  with check (
    buyer_id = auth.uid()
    and public.buyer_can_review_shop(shop_id)
  );

drop policy if exists "Buyers can update own shop reviews" on public.shop_reviews;
create policy "Buyers can update own shop reviews"
  on public.shop_reviews for update
  using (buyer_id = auth.uid())
  with check (
    buyer_id = auth.uid()
    and public.buyer_can_review_shop(shop_id)
  );

drop policy if exists "Buyers can delete own shop reviews" on public.shop_reviews;
create policy "Buyers can delete own shop reviews"
  on public.shop_reviews for delete
  using (buyer_id = auth.uid());

drop policy if exists "Product reviews are publicly readable" on public.product_reviews;
create policy "Product reviews are publicly readable"
  on public.product_reviews for select
  using (true);

drop policy if exists "Eligible buyers can insert product reviews" on public.product_reviews;
create policy "Eligible buyers can insert product reviews"
  on public.product_reviews for insert
  with check (
    buyer_id = auth.uid()
    and public.buyer_can_review_product(product_id)
  );

drop policy if exists "Buyers can update own product reviews" on public.product_reviews;
create policy "Buyers can update own product reviews"
  on public.product_reviews for update
  using (buyer_id = auth.uid())
  with check (
    buyer_id = auth.uid()
    and public.buyer_can_review_product(product_id)
  );

drop policy if exists "Buyers can delete own product reviews" on public.product_reviews;
create policy "Buyers can delete own product reviews"
  on public.product_reviews for delete
  using (buyer_id = auth.uid());
