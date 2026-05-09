alter table public.orders
  drop constraint if exists orders_shipping_method_check;

alter table public.orders
  add constraint orders_shipping_method_check
  check (
    shipping_method in (
      'courier_guy',
      'courier_guy_door_to_door',
      'pargo',
      'market_pickup'
    )
  );

alter table public.shops
alter column shipping_options
set default '[
  {"key": "courier_guy", "enabled": true, "price": 69.00},
  {"key": "courier_guy_door_to_door", "enabled": true, "price": 110.00},
  {"key": "pargo", "enabled": true, "price": 65.00},
  {"key": "market_pickup", "enabled": true, "price": 0.00}
]'::jsonb;

update public.shops
set shipping_options = public.shops.shipping_options || '[{"key": "courier_guy_door_to_door", "enabled": true, "price": 110.00}]'::jsonb
where jsonb_typeof(public.shops.shipping_options) = 'array'
  and not exists (
    select 1
    from jsonb_array_elements(public.shops.shipping_options) as option
    where option->>'key' = 'courier_guy_door_to_door'
  );

update public.products
set shipping_options = public.products.shipping_options || '[{"key": "courier_guy_door_to_door", "enabled": true, "price": 110.00}]'::jsonb
where jsonb_typeof(public.products.shipping_options) = 'array'
  and not exists (
    select 1
    from jsonb_array_elements(public.products.shipping_options) as option
    where option->>'key' = 'courier_guy_door_to_door'
  );
