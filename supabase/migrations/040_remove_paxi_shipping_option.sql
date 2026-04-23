alter table public.shops
alter column shipping_options
set default '[
  {"key": "courier_guy",   "enabled": true,  "price": 99.00},
  {"key": "pargo",         "enabled": true,  "price": 65.00},
  {"key": "market_pickup", "enabled": true,  "price": 0.00}
]'::jsonb;

update public.shops
set shipping_options = coalesce(
  (
    select jsonb_agg(option order by ordinality)
    from jsonb_array_elements(public.shops.shipping_options) with ordinality as filtered(option, ordinality)
    where option->>'key' <> 'paxi'
  ),
  '[]'::jsonb
)
where exists (
  select 1
  from jsonb_array_elements(public.shops.shipping_options) as current_options(option)
  where option->>'key' = 'paxi'
);

update public.products
set shipping_options = coalesce(
  (
    select jsonb_agg(option order by ordinality)
    from jsonb_array_elements(public.products.shipping_options) with ordinality as filtered(option, ordinality)
    where option->>'key' <> 'paxi'
  ),
  '[]'::jsonb
)
where jsonb_typeof(shipping_options) = 'array'
  and exists (
    select 1
    from jsonb_array_elements(public.products.shipping_options) as current_options(option)
    where option->>'key' = 'paxi'
  );
