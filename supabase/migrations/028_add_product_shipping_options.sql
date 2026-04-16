alter table public.products
  add column if not exists shipping_options jsonb not null default '[]'::jsonb;

update public.products as products
set shipping_options = coalesce(shops.shipping_options, '[]'::jsonb)
from public.shops as shops
where products.shop_id = shops.id
  and (
    products.shipping_options is null
    or products.shipping_options = '[]'::jsonb
  );
