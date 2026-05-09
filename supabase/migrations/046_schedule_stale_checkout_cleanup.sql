create extension if not exists pg_cron with schema extensions;

do $$
begin
  perform cron.unschedule('cancel-stale-checkouts-every-five-minutes');
exception
  when others then
    null;
end;
$$;

select cron.schedule(
  'cancel-stale-checkouts-every-five-minutes',
  '*/5 * * * *',
  'select public.cancel_stale_checkout_orders(30);'
);
