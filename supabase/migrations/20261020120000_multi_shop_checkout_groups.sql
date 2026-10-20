-- Multi-shop checkout: one payment, one escrow per shop.
--
-- A basket with items from several shops becomes one order per shop, each with
-- its own TradeSafe transaction (buyer + that artisan as seller), exactly like
-- a single-shop order. The buyer pays once: a TradeSafe deposit into their own
-- TradeSafe wallet for the basket total. The server then funds each shop's
-- transaction from that wallet (see _shared/checkout-groups.ts). Every artisan
-- is paid on their own delivery and refunds stay per shop.
--
-- checkout_groups tracks that one payment. Only the service role writes it;
-- buyers can read their own (the apps watch it while the payment completes).

create table if not exists public.checkout_groups (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  -- building: orders/transactions being created (never funded or expired);
  -- awaiting_payment: buyer's payment link is open; funded: every shop paid;
  -- cancelled: expired or replaced before payment; needs_attention: an admin
  -- must look (e.g. only part of the basket could be funded).
  status text not null default 'building'
    check (status in ('building', 'awaiting_payment', 'funded', 'cancelled', 'needs_attention')),
  buyer_token_id text not null,
  -- What the buyer owes across all shop transactions (incl. their share of fees).
  total_due numeric(12, 2) not null default 0 check (total_due >= 0),
  -- The TradeSafe deposit requested (whole rands; any cents over stay in the
  -- buyer's TradeSafe wallet and count towards their next checkout).
  deposit_amount numeric(12, 2) not null default 0 check (deposit_amount >= 0),
  deposit_intent_id text,
  deposit_url text,
  deposit_expires_at timestamptz,
  -- Only one funder at a time: the claim's owner id and when it was taken.
  funding_claim_id uuid,
  funding_claimed_at timestamptz,
  funded_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_checkout_groups_buyer on public.checkout_groups (buyer_id, created_at desc);
create index if not exists idx_checkout_groups_open on public.checkout_groups (status)
  where status in ('building', 'awaiting_payment', 'needs_attention');

alter table public.orders
  add column if not exists checkout_group_id uuid references public.checkout_groups(id) on delete set null,
  -- The buyer's deposit for this order's own TradeSafe transaction.
  add column if not exists tradesafe_buyer_deposit numeric(12, 2),
  -- Set the moment this order's transaction was paid from the buyer's wallet,
  -- so it is never paid twice.
  add column if not exists group_funded_at timestamptz;

create index if not exists idx_orders_checkout_group on public.orders (checkout_group_id)
  where checkout_group_id is not null;

alter table public.checkout_groups enable row level security;

drop policy if exists checkout_groups_buyer_read on public.checkout_groups;
create policy checkout_groups_buyer_read on public.checkout_groups
  for select to authenticated
  using (buyer_id = (select auth.uid()));

revoke all on public.checkout_groups from anon, authenticated;
grant select (id, buyer_id, status, total_due, deposit_amount, deposit_url, deposit_expires_at, funded_at, created_at, updated_at)
  on public.checkout_groups to authenticated;
grant all on public.checkout_groups to service_role;

-- Cancels specific unpaid checkout orders now and returns their stock, the same
-- way cancel_stale_checkout_orders does after 30 minutes. Used when a
-- multi-shop checkout fails part-way, so no shop is left holding stock.
create or replace function public.cancel_unpaid_checkout_orders(order_ids uuid[])
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
    where o.id = any(order_ids)
      and o.status = 'pending'
      and o.payment_provider = 'tradesafe'
      and o.payment_state in ('CREATED', 'checkout_created', 'INITIATED')
      and o.shipped_at is null
      and o.received_at is null
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

revoke execute on function public.cancel_unpaid_checkout_orders(uuid[]) from public, anon, authenticated;
grant execute on function public.cancel_unpaid_checkout_orders(uuid[]) to service_role;

-- Stale cleanup leaves multi-shop basket orders alone: a basket is funded or
-- expired as a whole by the funding step, so one shop can never be cancelled
-- while its sibling is being paid. Otherwise unchanged from 067.
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
      -- Multi-shop baskets expire as a whole (see _shared/checkout-groups.ts).
      and o.checkout_group_id is null
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

