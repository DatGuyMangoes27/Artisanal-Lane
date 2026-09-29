-- Row-aware readers for private profile fields. Additive: prepares clients for
-- column-level profile privacy without changing current access.

-- The signed-in account's own full profile.
create function public.get_my_profile() returns setof public.profiles
language sql stable security definer set search_path='' as $$
  select p.* from public.profiles p where p.id = (select auth.uid());
$$;
revoke all on function public.get_my_profile() from public, anon;
grant execute on function public.get_my_profile() to authenticated;

-- Buyer contact details for orders placed with the caller's own shops.
create function public.get_order_buyer_contacts(p_order_ids uuid[])
returns table(order_id uuid, buyer_id uuid, display_name text, email text, phone text)
language sql stable security definer set search_path='' as $$
  select o.id, p.id, p.display_name, p.email, p.phone
  from public.orders o
  join public.shops s on s.id = o.shop_id
  join public.profiles p on p.id = o.buyer_id
  where o.id = any(p_order_ids)
    and s.vendor_id = (select auth.uid())
  limit 500;
$$;
revoke all on function public.get_order_buyer_contacts(uuid[]) from public, anon;
grant execute on function public.get_order_buyer_contacts(uuid[]) to authenticated;
