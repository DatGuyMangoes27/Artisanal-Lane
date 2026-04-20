-- Soft-delete support for products so vendors can remove listings
-- even when they are referenced by historical order_items. A hard delete
-- would violate order_items.product_id foreign key; archiving preserves
-- order history while hiding the product from buyers and vendor lists.

alter table public.products
  add column if not exists archived_at timestamptz;

create index if not exists idx_products_archived_at
  on public.products (archived_at);

-- Buyer-facing policy now also excludes archived products.
drop policy if exists "Published products viewable by everyone" on public.products;
create policy "Published products viewable by everyone" on public.products
  for select
  using (is_published = true and archived_at is null);
