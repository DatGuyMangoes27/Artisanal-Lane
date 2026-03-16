create table if not exists admin_shop_notes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  note text not null,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_admin_shop_notes_shop_created
  on admin_shop_notes(shop_id, created_at desc);

alter table admin_shop_notes enable row level security;

create policy "admins_select_shop_notes"
  on admin_shop_notes for select
  using (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

create policy "admins_insert_shop_notes"
  on admin_shop_notes for insert
  with check (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );
