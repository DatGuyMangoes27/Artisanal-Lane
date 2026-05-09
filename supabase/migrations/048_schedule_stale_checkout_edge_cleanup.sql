create extension if not exists pg_net with schema extensions;

do $$
begin
  perform cron.unschedule('cancel-stale-checkouts-every-five-minutes');
exception
  when others then
    null;
end;
$$;

do $$
begin
  perform cron.unschedule('invoke-stale-checkout-cleanup-every-five-minutes');
exception
  when others then
    null;
end;
$$;

select cron.schedule(
  'invoke-stale-checkout-cleanup-every-five-minutes',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://byckurabenbunsbrzcpl.supabase.co/functions/v1/cleanup-stale-checkouts?minutes=30',
    headers := jsonb_build_object(
      'x-cleanup-secret',
      (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'stale_checkout_cleanup_secret'
        limit 1
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $$
);
