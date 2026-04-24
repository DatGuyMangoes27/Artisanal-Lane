alter table public.invite_codes
drop constraint if exists invite_codes_created_by_fkey;

alter table public.invite_codes
add constraint invite_codes_created_by_fkey
foreign key (created_by) references public.profiles(id) on delete set null;

alter table public.invite_codes
drop constraint if exists invite_codes_used_by_fkey;

alter table public.invite_codes
add constraint invite_codes_used_by_fkey
foreign key (used_by) references public.profiles(id) on delete set null;

alter table public.vendor_applications
drop constraint if exists vendor_applications_reviewed_by_fkey;

alter table public.vendor_applications
add constraint vendor_applications_reviewed_by_fkey
foreign key (reviewed_by) references public.profiles(id) on delete set null;

alter table public.orders
drop constraint if exists orders_buyer_id_fkey;

alter table public.orders
add constraint orders_buyer_id_fkey
foreign key (buyer_id) references public.profiles(id) on delete set null;

alter table public.orders
drop constraint if exists orders_shop_id_fkey;

alter table public.orders
add constraint orders_shop_id_fkey
foreign key (shop_id) references public.shops(id) on delete set null;

alter table public.order_items
drop constraint if exists order_items_product_id_fkey;

alter table public.order_items
add constraint order_items_product_id_fkey
foreign key (product_id) references public.products(id) on delete set null;

alter table public.disputes
drop constraint if exists disputes_raised_by_fkey;

alter table public.disputes
add constraint disputes_raised_by_fkey
foreign key (raised_by) references public.profiles(id) on delete set null;

alter table public.disputes
drop constraint if exists disputes_resolved_by_fkey;

alter table public.disputes
add constraint disputes_resolved_by_fkey
foreign key (resolved_by) references public.profiles(id) on delete set null;
