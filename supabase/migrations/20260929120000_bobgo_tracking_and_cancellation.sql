-- Bob Go tracking, cancellation and booking-retry support.
-- Additive follow-up to 20260817150500_add_bobgo_shipping_foundation.sql.
-- NOT applied to production yet: apply to the sandbox/dev branch first
-- (see docs/bobgo-go-live.md). Re-runnable: every statement is idempotent.
-- Live note: the foundation migration is recorded in production as version
-- 20260817132555 (add_bobgo_shipping_foundation); apply THIS file on its own
-- (apply_migration / SQL editor), not with `supabase db push`.

alter table public.orders
  add column if not exists bobgo_status_detail text,
  add column if not exists bobgo_last_event_at timestamptz,
  add column if not exists bobgo_tracking_events jsonb not null default '[]'::jsonb,
  add column if not exists bobgo_delivered_at timestamptz,
  add column if not exists bobgo_cancelled_at timestamptz,
  add column if not exists bobgo_cancel_error text,
  add column if not exists bobgo_booking_attempts integer not null default 0,
  add column if not exists bobgo_booked_at timestamptz,
  add column if not exists bobgo_booking_started_at timestamptz;

alter table public.orders
  drop constraint if exists orders_bobgo_booking_state_check;

alter table public.orders
  add constraint orders_bobgo_booking_state_check
  check (bobgo_booking_state in ('not_requested', 'booking', 'booked', 'failed', 'cancelled'));

-- The tracking poller and the retry sweep only look at Bob Go orders that are
-- still moving, so keep those lookups cheap.
create index if not exists orders_bobgo_open_shipments_idx
  on public.orders (bobgo_last_event_at nulls first)
  where shipping_method = 'bobgo_door_to_door'
    and bobgo_booking_state = 'booked'
    and bobgo_delivered_at is null
    and bobgo_cancelled_at is null;

create index if not exists orders_bobgo_pending_booking_idx
  on public.orders (paid_at)
  where shipping_method = 'bobgo_door_to_door'
    and bobgo_booking_state in ('not_requested', 'failed')
    and bobgo_shipment_id is null;

-- Webhooks are matched to orders by the Bob Go tracking reference.
create index if not exists orders_bobgo_tracking_number_idx
  on public.orders (tracking_number)
  where shipping_method = 'bobgo_door_to_door' and tracking_number is not null;

-- Orders stuck in 'booking' (function died after calling Bob Go) are NOT
-- re-booked blindly: bobgo-sync-tracking only adopts a shipment it can find on
-- Bob Go for the order and reports the rest for an admin to reconcile.
create index if not exists orders_bobgo_stuck_booking_idx
  on public.orders (bobgo_booking_started_at)
  where shipping_method = 'bobgo_door_to_door'
    and bobgo_booking_state = 'booking';

-- No RLS change: orders stay read-only for signed-in users (buyers read their
-- own orders, vendors their shop orders; see 20260927190000). Every Bob Go
-- column is written by Edge Functions with the service role only.
