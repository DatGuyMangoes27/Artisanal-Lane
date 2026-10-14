-- A recurring subscription stays usable for 5 days after its paid-through
-- date, so a failed card (PayFast retries) or a late renewal notice doesn't
-- hide the shop or block product edits. Cancelled subscriptions still end at
-- their paid-through date.
create or replace function public.vendor_subscription_is_active(target_vendor_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.vendor_subscriptions subscriptions
    where subscriptions.vendor_id = target_vendor_id
      and (
        (
          subscriptions.status in ('active', 'past_due')
          and subscriptions.cancelled_at is null
          and (
            subscriptions.current_period_end is null
            or subscriptions.current_period_end + interval '5 days' > now()
          )
        )
        or (
          subscriptions.status = 'cancelled'
          and subscriptions.current_period_end is not null
          and subscriptions.current_period_end > now()
        )
      )
  );
$$;
