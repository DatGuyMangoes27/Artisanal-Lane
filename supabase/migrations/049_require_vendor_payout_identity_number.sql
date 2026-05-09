update public.vendor_payout_profiles
set
  verification_status = 'action_required',
  status_notes = coalesce(
    nullif(status_notes, ''),
    'South African ID number is required for TradeSafe payouts.'
  ),
  updated_at = now()
where verification_status in ('submitted', 'under_review', 'verified')
  and nullif(btrim(identity_number), '') is null;

alter table public.vendor_payout_profiles
  drop constraint if exists vendor_payout_profiles_ready_requires_identity;

alter table public.vendor_payout_profiles
  add constraint vendor_payout_profiles_ready_requires_identity
  check (
    verification_status in ('not_started', 'action_required')
    or nullif(btrim(identity_number), '') is not null
  );
