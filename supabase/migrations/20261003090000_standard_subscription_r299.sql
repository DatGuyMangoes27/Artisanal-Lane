-- The standard artisan subscription is R299/month (founders: R199 for 12 months).
alter table public.vendor_subscriptions alter column amount set default 299.00;
