-- Web carts always carry a reservation token, but made-to-order lines do not
-- reserve or decrement stock. Ignore those lines when consuming reservations
-- so made-to-order-only and mixed baskets can both proceed to payment.
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
       and oi.is_made_to_order = false
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

revoke all on function public.consume_product_reservations(text, uuid)
  from public, anon, authenticated;
grant execute on function public.consume_product_reservations(text, uuid)
  to service_role;
