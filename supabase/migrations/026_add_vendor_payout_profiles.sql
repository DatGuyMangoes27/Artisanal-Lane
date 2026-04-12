alter table profiles
  add column if not exists vendor_approved_seen_at timestamptz;

create table if not exists vendor_payout_profiles (
  vendor_id uuid primary key references profiles(id) on delete cascade,
  account_holder_name text not null,
  bank_name text not null,
  account_number text not null,
  branch_code text not null,
  account_type text not null,
  registered_phone text not null,
  registered_email text not null,
  identity_number text,
  business_registration_number text,
  verification_status text not null default 'not_started'
    check (verification_status in ('not_started', 'submitted', 'under_review', 'verified', 'action_required')),
  status_notes text,
  reviewed_by uuid references profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table vendor_payout_profiles enable row level security;

create policy "Vendors can view own payout profile"
  on vendor_payout_profiles for select
  using (auth.uid() = vendor_id);

create policy "Vendors can insert own payout profile"
  on vendor_payout_profiles for insert
  with check (auth.uid() = vendor_id);

create policy "Vendors can update own payout profile submission"
  on vendor_payout_profiles for update
  using (auth.uid() = vendor_id)
  with check (
    auth.uid() = vendor_id
    and verification_status in ('submitted', 'under_review', 'verified', 'action_required')
  );

create policy "Admins can view payout profiles"
  on vendor_payout_profiles for select
  using (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

create policy "Admins can update payout profiles"
  on vendor_payout_profiles for update
  using (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  )
  with check (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

create or replace function set_vendor_payout_profiles_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_vendor_payout_profiles_updated_at on vendor_payout_profiles;

create trigger update_vendor_payout_profiles_updated_at
  before update on vendor_payout_profiles
  for each row execute procedure set_vendor_payout_profiles_updated_at();
