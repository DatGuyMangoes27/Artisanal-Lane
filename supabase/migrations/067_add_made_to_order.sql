-- ============================================================
-- Made-to-order fulfillment
-- ============================================================
-- Lets artisans offer products as "made to order": buyable even when
-- out of stock (or with no inventory at all), with an optional separate
-- price, a lead-time range, an optional buyer custom-request note, and an
-- optional capacity cap on open (not-yet-shipped) made-to-order units.

alter table public.products
  add column if not exists fulfillment_mode text not null default 'stocked'
    check (fulfillment_mode in ('stocked', 'made_to_order', 'stocked_with_mto')),
  add column if not exists made_to_order_price numeric(10, 2),
  add column if not exists made_to_order_lead_min_days int
    check (made_to_order_lead_min_days is null or made_to_order_lead_min_days >= 0),
  add column if not exists made_to_order_lead_max_days int
    check (made_to_order_lead_max_days is null or made_to_order_lead_max_days >= 0),
  add column if not exists made_to_order_capacity int
    check (made_to_order_capacity is null or made_to_order_capacity >= 0),
  add column if not exists made_to_order_allow_custom_note boolean not null default false;

alter table public.cart_items
  add column if not exists is_made_to_order boolean not null default false,
  add column if not exists custom_note text;

alter table public.order_items
  add column if not exists is_made_to_order boolean not null default false,
  add column if not exists custom_note text,
  add column if not exists lead_time_min_days int,
  add column if not exists lead_time_max_days int;

-- Count made-to-order units that the artisan still has to produce, i.e. orders
-- that are placed but not yet shipped/delivered/completed/cancelled. Used to
-- enforce the optional per-product capacity cap. Security definer so server-side
-- callers can count across all buyers' orders without tripping order RLS.
create or replace function public.made_to_order_open_units(product_id_input uuid)
returns int
language sql
security definer
set search_path = public
as $$
  select coalesce(sum(oi.quantity), 0)::int
    from public.order_items oi
    join public.orders o on o.id = oi.order_id
   where oi.product_id = product_id_input
     and oi.is_made_to_order = true
     and o.status in ('pending', 'paid', 'disputed');
$$;

grant execute on function public.made_to_order_open_units(uuid) to anon, authenticated, service_role;

-- Made-to-order lines never decrement inventory, so the stale-checkout cleanup
-- must not "restore" stock for them (that would inflate inventory). Re-create
-- cancel_stale_checkout_orders to skip is_made_to_order items when restoring.
create or replace function public.cancel_stale_checkout_orders(
  stale_minutes integer default 30
)
returns table (
  order_id uuid,
  tradesafe_transaction_id text,
  restored_item_count integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with target_orders as (
    select o.id, o.tradesafe_transaction_id
    from public.orders o
    where o.status = 'pending'
      and o.payment_provider = 'tradesafe'
      and o.payment_state in ('CREATED', 'checkout_created', 'INITIATED')
      and o.shipped_at is null
      and o.received_at is null
      and o.created_at < now() - make_interval(mins => greatest(stale_minutes, 1))
    for update
  ),
  restored_variants as (
    update public.product_variants pv
       set stock_qty = pv.stock_qty + oi.quantity,
           updated_at = now()
      from public.order_items oi
      join target_orders target on target.id = oi.order_id
     where oi.variant_id is not null
       and oi.is_made_to_order = false
       and pv.id = oi.variant_id
     returning oi.order_id as restored_order_id, oi.id as order_item_id
  ),
  restored_products as (
    update public.products p
       set stock_qty = p.stock_qty + oi.quantity,
           updated_at = now()
      from public.order_items oi
      join target_orders target on target.id = oi.order_id
     where oi.variant_id is null
       and oi.is_made_to_order = false
       and p.id = oi.product_id
     returning oi.order_id as restored_order_id, oi.id as order_item_id
  ),
  restored_items as (
    select restored_order_id, order_item_id from restored_variants
    union all
    select restored_order_id, order_item_id from restored_products
  ),
  cancelled_orders as (
    update public.orders o
       set status = 'cancelled',
           payment_state = 'STALE_CHECKOUT_CANCELLED',
           payment_url = null,
           updated_at = now()
      from target_orders target
     where o.id = target.id
     returning o.id, target.tradesafe_transaction_id
  ),
  cancelled_escrows as (
    update public.escrow_transactions et
       set status = 'cancelled',
           provider_state = 'STALE_CHECKOUT_CANCELLED'
      from target_orders target
     where et.order_id = target.id
     returning et.order_id
  )
  select
    cancelled_orders.id as order_id,
    cancelled_orders.tradesafe_transaction_id,
    coalesce(count(restored_items.order_item_id), 0)::integer as restored_item_count
  from cancelled_orders
  left join restored_items on restored_items.restored_order_id = cancelled_orders.id
  group by cancelled_orders.id, cancelled_orders.tradesafe_transaction_id;
end;
$$;
