-- ============================================================
-- Product colour variants
-- ============================================================

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  color_name text not null,
  price numeric(10, 2) not null,
  compare_at_price numeric(10, 2),
  stock_qty int not null default 0 check (stock_qty >= 0),
  images jsonb not null default '[]'::jsonb,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id, color_name)
);

create index if not exists idx_product_variants_product_id
  on public.product_variants(product_id, sort_order asc, created_at asc);

create index if not exists idx_product_variants_active
  on public.product_variants(is_active);

alter table public.cart_items
  add column if not exists variant_id uuid references public.product_variants(id) on delete set null;

alter table public.order_items
  add column if not exists variant_id uuid references public.product_variants(id) on delete set null,
  add column if not exists variant_name text,
  add column if not exists variant_image text;

alter table public.product_variants enable row level security;

create or replace function public.sync_product_variant_summary(target_product_id uuid)
returns void
language plpgsql
as $$
declare
  summary_variant record;
  total_stock int;
begin
  select pv.price,
         pv.compare_at_price,
         pv.images
    into summary_variant
    from public.product_variants pv
   where pv.product_id = target_product_id
     and pv.is_active = true
   order by pv.sort_order asc, pv.price asc, pv.created_at asc
   limit 1;

  select coalesce(sum(pv.stock_qty), 0)
    into total_stock
    from public.product_variants pv
   where pv.product_id = target_product_id
     and pv.is_active = true;

  if summary_variant is null then
    return;
  end if;

  update public.products
     set price = summary_variant.price,
         compare_at_price = summary_variant.compare_at_price,
         stock_qty = total_stock,
         images = summary_variant.images,
         updated_at = now()
   where id = target_product_id;
end;
$$;

create or replace function public.handle_product_variant_summary_sync()
returns trigger
language plpgsql
as $$
begin
  perform public.sync_product_variant_summary(coalesce(new.product_id, old.product_id));
  return coalesce(new, old);
end;
$$;

create or replace function public.decrement_variant_stock(variant_id_input uuid, qty_input int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_stock int;
begin
  select stock_qty
    into current_stock
    from public.product_variants
   where id = variant_id_input
   for update;

  if current_stock is null then
    raise exception 'Variant not found';
  end if;

  if current_stock < qty_input then
    raise exception 'Insufficient variant stock';
  end if;

  update public.product_variants
     set stock_qty = stock_qty - qty_input,
         updated_at = now()
   where id = variant_id_input;
end;
$$;

drop trigger if exists update_product_variants_updated_at on public.product_variants;
create trigger update_product_variants_updated_at
  before update on public.product_variants
  for each row execute function public.update_updated_at_column();

drop trigger if exists sync_product_variants_after_change on public.product_variants;
create trigger sync_product_variants_after_change
  after insert or update or delete on public.product_variants
  for each row execute function public.handle_product_variant_summary_sync();

drop policy if exists "Active product variants are publicly readable" on public.product_variants;
create policy "Active product variants are publicly readable"
  on public.product_variants for select
  using (
    is_active = true
    and exists (
      select 1
      from public.products p
      where p.id = product_variants.product_id
        and p.is_published = true
    )
  );

drop policy if exists "Vendors can view own product variants" on public.product_variants;
create policy "Vendors can view own product variants"
  on public.product_variants for select
  using (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.vendor_id = auth.uid()
    )
  );

drop policy if exists "Vendors can insert own product variants" on public.product_variants;
create policy "Vendors can insert own product variants"
  on public.product_variants for insert
  with check (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.vendor_id = auth.uid()
    )
  );

drop policy if exists "Vendors can update own product variants" on public.product_variants;
create policy "Vendors can update own product variants"
  on public.product_variants for update
  using (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.vendor_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.vendor_id = auth.uid()
    )
  );

drop policy if exists "Vendors can delete own product variants" on public.product_variants;
create policy "Vendors can delete own product variants"
  on public.product_variants for delete
  using (
    exists (
      select 1
      from public.products p
      join public.shops s on s.id = p.shop_id
      where p.id = product_variants.product_id
        and s.vendor_id = auth.uid()
    )
  );

alter table public.cart_items drop constraint if exists cart_items_cart_id_product_id_key;

drop index if exists idx_cart_items_cart_product_variant_unique;
create unique index idx_cart_items_cart_product_variant_unique
  on public.cart_items(
    cart_id,
    product_id,
    coalesce(variant_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );
