create or replace function public.decrement_product_stock(product_id_input uuid, qty_input int)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_stock int;
begin
  select stock_qty
    into current_stock
    from public.products
   where id = product_id_input
   for update;

  if current_stock is null then
    raise exception 'Product not found';
  end if;

  if current_stock < qty_input then
    raise exception 'Insufficient product stock';
  end if;

  update public.products
     set stock_qty = stock_qty - qty_input,
         updated_at = now()
   where id = product_id_input;
end;
$$;
