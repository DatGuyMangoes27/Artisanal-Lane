alter table stationery_requests
  add column if not exists admin_notes text,
  add column if not exists tracking_number text,
  add column if not exists courier_name text,
  add column if not exists fulfilled_by uuid references profiles(id) on delete set null,
  add column if not exists fulfilled_at timestamptz;

create policy "Admins can view stationery requests" on stationery_requests
  for select using (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

create policy "Admins can update stationery requests" on stationery_requests
  for update using (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );
