create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

do $$
begin
  perform cron.unschedule('send-receipt-reminders-daily');
exception
  when others then
    null;
end;
$$;

select cron.schedule(
  'send-receipt-reminders-daily',
  '0 7 * * *',
  $$
  select net.http_post(
    url := 'https://byckurabenbunsbrzcpl.supabase.co/functions/v1/send-receipt-reminders',
    headers := jsonb_build_object(
      'x-receipt-reminder-secret',
      (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'receipt_reminder_secret'
        limit 1
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $$
);
