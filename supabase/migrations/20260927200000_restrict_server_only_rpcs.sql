-- Stock and stale-checkout functions are called only by service-role edge
-- functions (create-checkout, cleanup-stale-checkouts). Remove public RPC access.
revoke execute on function public.cancel_stale_checkout_orders(integer) from public, anon, authenticated;
revoke execute on function public.decrement_product_stock(uuid, integer) from public, anon, authenticated;
revoke execute on function public.decrement_variant_stock(uuid, integer) from public, anon, authenticated;
grant execute on function public.cancel_stale_checkout_orders(integer) to service_role;
grant execute on function public.decrement_product_stock(uuid, integer) to service_role;
grant execute on function public.decrement_variant_stock(uuid, integer) to service_role;
