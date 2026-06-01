create or replace function public.ensure_archived_order_history_shop()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  shop_uuid uuid;
begin
  select id
    into shop_uuid
    from public.shops
   where slug = 'archived-order-history'
   limit 1;

  if shop_uuid is null then
    insert into public.shops (
      name,
      slug,
      bio,
      location,
      shipping_options,
      is_active,
      is_offline
    ) values (
      'Archived seller',
      'archived-order-history',
      'Preserves historical order records after a seller account is removed.',
      'Archived',
      '[]'::jsonb,
      false,
      true
    )
    returning id into shop_uuid;
  end if;

  return shop_uuid;
end;
$$;

create or replace function public.ensure_archived_order_history_product()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  shop_uuid uuid;
  product_uuid uuid;
begin
  shop_uuid := public.ensure_archived_order_history_shop();

  select id
    into product_uuid
    from public.products
   where shop_id = shop_uuid
     and title = 'Archived order item'
   limit 1;

  if product_uuid is null then
    insert into public.products (
      shop_id,
      title,
      description,
      price,
      stock_qty,
      images,
      is_published,
      tags,
      shipping_options,
      archived_at
    ) values (
      shop_uuid,
      'Archived order item',
      'Preserves historical order item records after a product is removed.',
      0,
      0,
      '[]'::jsonb,
      false,
      array['archived-order-history'],
      '[]'::jsonb,
      now()
    )
    returning id into product_uuid;
  end if;

  return product_uuid;
end;
$$;

create or replace function public.set_order_history_placeholder_shop()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.shop_id is null then
    new.shop_id := public.ensure_archived_order_history_shop();
  end if;
  return new;
end;
$$;

create or replace function public.set_order_item_history_placeholder_product()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.product_id is null then
    new.product_id := public.ensure_archived_order_history_product();
  end if;
  return new;
end;
$$;

drop trigger if exists set_order_history_placeholder_shop_trigger on public.orders;
create trigger set_order_history_placeholder_shop_trigger
  before insert or update of shop_id on public.orders
  for each row
  when (new.shop_id is null)
  execute function public.set_order_history_placeholder_shop();

drop trigger if exists set_order_item_history_placeholder_product_trigger on public.order_items;
create trigger set_order_item_history_placeholder_product_trigger
  before insert or update of product_id on public.order_items
  for each row
  when (new.product_id is null)
  execute function public.set_order_item_history_placeholder_product();

update public.orders
   set shop_id = public.ensure_archived_order_history_shop()
 where shop_id is null;

update public.order_items
   set product_id = public.ensure_archived_order_history_product()
 where product_id is null;
