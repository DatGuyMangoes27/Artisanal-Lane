create table public.shop_coupons (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  code text not null,
  description text,
  discount_type text not null,
  discount_value numeric(10, 2) not null,
  scope text not null default 'store',
  minimum_subtotal numeric(10, 2) not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_coupons_code_format check (
    code = upper(btrim(code))
    and char_length(code) between 3 and 32
    and code ~ '^[A-Z0-9_-]+$'
  ),
  constraint shop_coupons_discount_type check (
    discount_type in ('percentage', 'fixed')
  ),
  constraint shop_coupons_discount_value check (
    discount_value > 0
    and (discount_type <> 'percentage' or discount_value <= 100)
  ),
  constraint shop_coupons_scope check (scope in ('store', 'products')),
  constraint shop_coupons_minimum_subtotal check (minimum_subtotal >= 0),
  constraint shop_coupons_date_range check (
    starts_at is null or ends_at is null or ends_at > starts_at
  )
);

create unique index shop_coupons_shop_code_unique
  on public.shop_coupons (shop_id, code);

create index shop_coupons_shop_created_idx
  on public.shop_coupons (shop_id, created_at desc);

create index shop_coupons_active_lookup_idx
  on public.shop_coupons (shop_id, code)
  where is_active = true;

create table public.shop_coupon_products (
  coupon_id uuid not null references public.shop_coupons(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (coupon_id, product_id)
);

create index shop_coupon_products_product_idx
  on public.shop_coupon_products (product_id);

create or replace function public.validate_shop_coupon_product()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  coupon_shop_id uuid;
  product_shop_id uuid;
begin
  select shop_id into coupon_shop_id
  from public.shop_coupons
  where id = new.coupon_id;

  select shop_id into product_shop_id
  from public.products
  where id = new.product_id;

  if coupon_shop_id is null or product_shop_id is null or coupon_shop_id <> product_shop_id then
    raise exception 'Coupon products must belong to the coupon shop.';
  end if;

  return new;
end;
$$;

create trigger validate_shop_coupon_product_trigger
  before insert or update on public.shop_coupon_products
  for each row execute function public.validate_shop_coupon_product();

create trigger update_shop_coupons_updated_at
  before update on public.shop_coupons
  for each row execute function public.update_updated_at_column();

alter table public.orders
  add column coupon_id uuid references public.shop_coupons(id) on delete set null,
  add column coupon_code text,
  add column subtotal_before_discount numeric(10, 2),
  add column discount_amount numeric(10, 2) not null default 0,
  add constraint orders_discount_amount_nonnegative check (discount_amount >= 0),
  add constraint orders_discount_not_above_subtotal check (
    subtotal_before_discount is null or discount_amount <= subtotal_before_discount
  );

create index orders_coupon_id_idx
  on public.orders (coupon_id)
  where coupon_id is not null;

alter table public.shop_coupons enable row level security;
alter table public.shop_coupon_products enable row level security;

create policy "Vendors can view own coupons"
on public.shop_coupons for select
to authenticated
using (
  shop_id in (
    select id from public.shops where vendor_id = (select auth.uid())
  )
);

create policy "Vendors can create own coupons"
on public.shop_coupons for insert
to authenticated
with check (
  shop_id in (
    select id from public.shops where vendor_id = (select auth.uid())
  )
);

create policy "Vendors can update own coupons"
on public.shop_coupons for update
to authenticated
using (
  shop_id in (
    select id from public.shops where vendor_id = (select auth.uid())
  )
)
with check (
  shop_id in (
    select id from public.shops where vendor_id = (select auth.uid())
  )
);

create policy "Vendors can delete own coupons"
on public.shop_coupons for delete
to authenticated
using (
  shop_id in (
    select id from public.shops where vendor_id = (select auth.uid())
  )
);

create policy "Vendors can view own coupon products"
on public.shop_coupon_products for select
to authenticated
using (
  coupon_id in (
    select id from public.shop_coupons
    where shop_id in (
      select id from public.shops where vendor_id = (select auth.uid())
    )
  )
);

create policy "Vendors can create own coupon products"
on public.shop_coupon_products for insert
to authenticated
with check (
  coupon_id in (
    select id from public.shop_coupons
    where shop_id in (
      select id from public.shops where vendor_id = (select auth.uid())
    )
  )
  and product_id in (
    select id from public.products
    where shop_id in (
      select id from public.shops where vendor_id = (select auth.uid())
    )
  )
);

create policy "Vendors can delete own coupon products"
on public.shop_coupon_products for delete
to authenticated
using (
  coupon_id in (
    select id from public.shop_coupons
    where shop_id in (
      select id from public.shops where vendor_id = (select auth.uid())
    )
  )
);

grant select, insert, update, delete on table public.shop_coupons to authenticated;
grant select, insert, delete on table public.shop_coupon_products to authenticated;
grant select, insert, update, delete on table public.shop_coupons to service_role;
grant select, insert, update, delete on table public.shop_coupon_products to service_role;

revoke all on function public.validate_shop_coupon_product() from public;
grant execute on function public.validate_shop_coupon_product() to authenticated, service_role;
