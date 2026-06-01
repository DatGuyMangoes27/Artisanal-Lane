create table if not exists public.product_reservations (
  id uuid primary key default gen_random_uuid(),
  reservation_token text not null,
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  quantity int not null check (quantity > 0),
  status text not null default 'active'
    check (status in ('active', 'consumed', 'released', 'expired')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_product_reservations_active_token_item
  on public.product_reservations (
    reservation_token,
    product_id,
    coalesce(variant_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status = 'active';

create index if not exists idx_product_reservations_token_status
  on public.product_reservations (reservation_token, status);

create index if not exists idx_product_reservations_expiry
  on public.product_reservations (expires_at)
  where status = 'active';

drop trigger if exists update_product_reservations_updated_at on public.product_reservations;
create trigger update_product_reservations_updated_at
  before update on public.product_reservations
  for each row execute function public.update_updated_at_column();

alter table public.product_reservations enable row level security;

drop policy if exists "Service role can manage product reservations" on public.product_reservations;
create policy "Service role can manage product reservations"
  on public.product_reservations for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create or replace function public.reserve_product_stock(
  reservation_token_input text,
  product_id_input uuid,
  variant_id_input uuid default null,
  quantity_input int default 1,
  expires_at_input timestamptz default now() + interval '48 hours'
)
returns table (
  reservation_id uuid,
  reserved_quantity int,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_reservation public.product_reservations%rowtype;
  current_stock int;
  quantity_delta int;
  target_reservation_id uuid;
begin
  if reservation_token_input is null or length(trim(reservation_token_input)) = 0 then
    raise exception 'Reservation token is required';
  end if;

  if quantity_input <= 0 then
    raise exception 'Reservation quantity must be greater than zero';
  end if;

  if variant_id_input is not null then
    select pv.stock_qty
      into current_stock
      from public.product_variants pv
     where pv.id = variant_id_input
       and pv.product_id = product_id_input
     for update;
  else
    select p.stock_qty
      into current_stock
      from public.products p
     where p.id = product_id_input
     for update;
  end if;

  if current_stock is null then
    raise exception 'Product not found';
  end if;

  select *
    into existing_reservation
    from public.product_reservations pr
   where pr.reservation_token = reservation_token_input
     and pr.product_id = product_id_input
     and (
       (variant_id_input is null and pr.variant_id is null)
       or pr.variant_id = variant_id_input
     )
     and pr.status = 'active'
   for update;

  quantity_delta = quantity_input - coalesce(existing_reservation.quantity, 0);

  if quantity_delta > current_stock then
    raise exception 'Insufficient stock for reservation';
  end if;

  if quantity_delta > 0 then
    if variant_id_input is not null then
      update public.product_variants
         set stock_qty = stock_qty - quantity_delta,
             updated_at = now()
       where id = variant_id_input;
    else
      update public.products
         set stock_qty = stock_qty - quantity_delta,
             updated_at = now()
       where id = product_id_input;
    end if;
  elsif quantity_delta < 0 then
    if variant_id_input is not null then
      update public.product_variants
         set stock_qty = stock_qty + abs(quantity_delta),
             updated_at = now()
       where id = variant_id_input;
    else
      update public.products
         set stock_qty = stock_qty + abs(quantity_delta),
             updated_at = now()
       where id = product_id_input;
    end if;
  end if;

  if existing_reservation.id is null then
    insert into public.product_reservations (
      reservation_token,
      product_id,
      variant_id,
      quantity,
      expires_at
    )
    values (
      reservation_token_input,
      product_id_input,
      variant_id_input,
      quantity_input,
      expires_at_input
    )
    returning id into target_reservation_id;
  else
    update public.product_reservations
       set quantity = quantity_input,
           expires_at = expires_at_input,
           updated_at = now()
     where id = existing_reservation.id
     returning id into target_reservation_id;
  end if;

  return query
  select target_reservation_id, quantity_input, expires_at_input;
end;
$$;

create or replace function public.release_product_reservation(
  reservation_token_input text,
  product_id_input uuid,
  variant_id_input uuid default null,
  next_status text default 'released'
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  reservation public.product_reservations%rowtype;
begin
  select *
    into reservation
    from public.product_reservations pr
   where pr.reservation_token = reservation_token_input
     and pr.product_id = product_id_input
     and (
       (variant_id_input is null and pr.variant_id is null)
       or pr.variant_id = variant_id_input
     )
     and pr.status = 'active'
   for update;

  if reservation.id is null then
    return 0;
  end if;

  if reservation.variant_id is not null then
    update public.product_variants
       set stock_qty = stock_qty + reservation.quantity,
           updated_at = now()
     where id = reservation.variant_id;
  else
    update public.products
       set stock_qty = stock_qty + reservation.quantity,
           updated_at = now()
     where id = reservation.product_id;
  end if;

  update public.product_reservations
     set status = next_status,
         updated_at = now()
   where id = reservation.id;

  return reservation.quantity;
end;
$$;

create or replace function public.release_all_product_reservations(
  reservation_token_input text,
  next_status text default 'released'
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  reservation public.product_reservations%rowtype;
  restored_count int := 0;
begin
  for reservation in
    select *
      from public.product_reservations pr
     where pr.reservation_token = reservation_token_input
       and pr.status = 'active'
     for update
  loop
    if reservation.variant_id is not null then
      update public.product_variants
         set stock_qty = stock_qty + reservation.quantity,
             updated_at = now()
       where id = reservation.variant_id;
    else
      update public.products
         set stock_qty = stock_qty + reservation.quantity,
             updated_at = now()
       where id = reservation.product_id;
    end if;

    update public.product_reservations
       set status = next_status,
           updated_at = now()
     where id = reservation.id;

    restored_count = restored_count + reservation.quantity;
  end loop;

  return restored_count;
end;
$$;

create or replace function public.consume_product_reservations(
  reservation_token_input text,
  order_id_input uuid
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  item record;
  reservation public.product_reservations%rowtype;
  consumed_count int := 0;
  excess_quantity int;
begin
  for item in
    select oi.product_id, oi.variant_id, sum(oi.quantity)::int as quantity
      from public.order_items oi
     where oi.order_id = order_id_input
     group by oi.product_id, oi.variant_id
  loop
    select *
      into reservation
      from public.product_reservations pr
     where pr.reservation_token = reservation_token_input
       and pr.product_id = item.product_id
       and (
         (item.variant_id is null and pr.variant_id is null)
         or pr.variant_id = item.variant_id
       )
       and pr.status = 'active'
       and pr.expires_at > now()
     for update;

    if reservation.id is null then
      raise exception 'Missing active reservation for order item';
    end if;

    if reservation.quantity < item.quantity then
      raise exception 'Reservation quantity is lower than order quantity';
    end if;

    excess_quantity = reservation.quantity - item.quantity;
    if excess_quantity > 0 then
      if reservation.variant_id is not null then
        update public.product_variants
           set stock_qty = stock_qty + excess_quantity,
               updated_at = now()
         where id = reservation.variant_id;
      else
        update public.products
           set stock_qty = stock_qty + excess_quantity,
               updated_at = now()
         where id = reservation.product_id;
      end if;
    end if;

    update public.product_reservations
       set status = 'consumed',
           order_id = order_id_input,
           quantity = item.quantity,
           updated_at = now()
     where id = reservation.id;

    consumed_count = consumed_count + item.quantity;
  end loop;

  return consumed_count;
end;
$$;

create or replace function public.release_all_expired_product_reservations(
  now_input timestamptz default now()
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  reservation public.product_reservations%rowtype;
  restored_count int := 0;
begin
  for reservation in
    select *
      from public.product_reservations pr
     where pr.status = 'active'
       and pr.expires_at <= now_input
     for update
  loop
    if reservation.variant_id is not null then
      update public.product_variants
         set stock_qty = stock_qty + reservation.quantity,
             updated_at = now()
       where id = reservation.variant_id;
    else
      update public.products
         set stock_qty = stock_qty + reservation.quantity,
             updated_at = now()
       where id = reservation.product_id;
    end if;

    update public.product_reservations
       set status = 'expired',
           updated_at = now()
     where id = reservation.id;

    restored_count = restored_count + reservation.quantity;
  end loop;

  return restored_count;
end;
$$;

create or replace function public.expire_product_reservations(
  now_input timestamptz default now()
)
returns int
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.release_all_expired_product_reservations(now_input);
end;
$$;

revoke all on function public.reserve_product_stock(text, uuid, uuid, int, timestamptz) from public, anon, authenticated;
revoke all on function public.release_product_reservation(text, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.release_all_product_reservations(text, text) from public, anon, authenticated;
revoke all on function public.consume_product_reservations(text, uuid) from public, anon, authenticated;
revoke all on function public.release_all_expired_product_reservations(timestamptz) from public, anon, authenticated;
revoke all on function public.expire_product_reservations(timestamptz) from public, anon, authenticated;

grant execute on function public.reserve_product_stock(text, uuid, uuid, int, timestamptz) to service_role;
grant execute on function public.release_product_reservation(text, uuid, uuid, text) to service_role;
grant execute on function public.release_all_product_reservations(text, text) to service_role;
grant execute on function public.consume_product_reservations(text, uuid) to service_role;
grant execute on function public.release_all_expired_product_reservations(timestamptz) to service_role;
grant execute on function public.expire_product_reservations(timestamptz) to service_role;
