create or replace function public.coerce_vendor_payout_identity_status()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if nullif(btrim(new.identity_number), '') is null
     and new.verification_status in ('submitted', 'under_review', 'verified') then
    new.verification_status = 'action_required';
    new.status_notes = coalesce(
      nullif(new.status_notes, ''),
      'South African ID number is required for TradeSafe payouts.'
    );
  end if;

  return new;
end;
$$;

drop trigger if exists coerce_vendor_payout_identity_status
  on public.vendor_payout_profiles;

create trigger coerce_vendor_payout_identity_status
before insert or update on public.vendor_payout_profiles
for each row
execute function public.coerce_vendor_payout_identity_status();

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
