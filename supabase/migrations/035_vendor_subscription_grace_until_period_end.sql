-- Allow cancelled subscriptions to remain "active" until the paid-through
-- period ends, so artisans keep full store access between a cancellation and
-- their current_period_end.

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
          subscriptions.status = 'active'
          and subscriptions.cancelled_at is null
          and (
            subscriptions.current_period_end is null
            or subscriptions.current_period_end > now()
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
