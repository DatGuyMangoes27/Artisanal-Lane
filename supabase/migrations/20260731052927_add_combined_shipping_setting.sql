alter table public.shops
add column if not exists combined_shipping_enabled boolean not null default true;

comment on column public.shops.combined_shipping_enabled is
  'When true, checkout charges the highest applicable shipping rate once per shop order. When false, shipping is charged per item.';
