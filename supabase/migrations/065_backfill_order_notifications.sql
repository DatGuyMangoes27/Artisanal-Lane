insert into public.notifications (
  user_id,
  title,
  body,
  notification_type,
  event_key,
  data,
  created_at
)
select
  o.buyer_id,
  'Order confirmed',
  'Your order from ' || coalesce(nullif(s.name, ''), 'Artisan Lane') || ' is confirmed.',
  'order_update',
  'order_update:' || o.id::text || ':paid:buyer',
  jsonb_build_object(
    'type', 'order_update',
    'order_id', o.id::text,
    'event', 'paid',
    'recipient_role', 'buyer'
  ),
  coalesce(o.paid_at, o.created_at)
from public.orders o
left join public.shops s on s.id = o.shop_id
where o.buyer_id is not null
  and o.paid_at is not null
on conflict (user_id, event_key) do nothing;

insert into public.notifications (
  user_id,
  title,
  body,
  notification_type,
  event_key,
  data,
  created_at
)
select
  s.vendor_id,
  'New order received',
  'You have a new paid order for ' || coalesce(nullif(s.name, ''), 'Artisan Lane') || '.',
  'order_update',
  'order_update:' || o.id::text || ':paid:vendor',
  jsonb_build_object(
    'type', 'order_update',
    'order_id', o.id::text,
    'event', 'paid',
    'recipient_role', 'vendor'
  ),
  coalesce(o.paid_at, o.created_at)
from public.orders o
join public.shops s on s.id = o.shop_id
where s.vendor_id is not null
  and o.paid_at is not null
on conflict (user_id, event_key) do nothing;

insert into public.notifications (
  user_id,
  title,
  body,
  notification_type,
  event_key,
  data,
  created_at
)
select
  o.buyer_id,
  'Order completed',
  'Your order from ' || coalesce(nullif(s.name, ''), 'Artisan Lane') || ' is complete.',
  'order_update',
  'order_update:' || o.id::text || ':completed:buyer',
  jsonb_build_object(
    'type', 'order_update',
    'order_id', o.id::text,
    'event', 'completed',
    'recipient_role', 'buyer'
  ),
  coalesce(o.updated_at, o.paid_at, o.created_at)
from public.orders o
left join public.shops s on s.id = o.shop_id
where o.buyer_id is not null
  and o.status = 'completed'
on conflict (user_id, event_key) do nothing;

insert into public.notifications (
  user_id,
  title,
  body,
  notification_type,
  event_key,
  data,
  created_at
)
select
  s.vendor_id,
  'Order completed',
  'An order for ' || coalesce(nullif(s.name, ''), 'Artisan Lane') || ' was completed and funds were released.',
  'order_update',
  'order_update:' || o.id::text || ':completed:vendor',
  jsonb_build_object(
    'type', 'order_update',
    'order_id', o.id::text,
    'event', 'completed',
    'recipient_role', 'vendor'
  ),
  coalesce(o.updated_at, o.paid_at, o.created_at)
from public.orders o
join public.shops s on s.id = o.shop_id
where s.vendor_id is not null
  and o.status = 'completed'
on conflict (user_id, event_key) do nothing;
