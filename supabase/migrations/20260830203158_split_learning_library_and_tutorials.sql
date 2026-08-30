-- Separate public product tutorials from the artisan-only business library.
-- Existing Artisan Lane walkthrough videos become tutorials; independent
-- videos, articles, and podcasts (including Pricing and New wave knitting)
-- remain in the vendor Library.

alter table public.learning_resources
  add column if not exists destination text;

update public.learning_resources
set destination = case
  when type = 'video' and author ilike 'Artisan Lane%' then 'tutorial'
  else 'library'
end
where destination is null;

alter table public.learning_resources
  alter column destination set default 'library',
  alter column destination set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'learning_resources_destination_check'
      and conrelid = 'public.learning_resources'::regclass
  ) then
    alter table public.learning_resources
      add constraint learning_resources_destination_check
      check (destination in ('library', 'tutorial'));
  end if;
end;
$$;

drop policy if exists "Published learning resources are public"
  on public.learning_resources;
drop policy if exists "Published tutorials are public"
  on public.learning_resources;
create policy "Published tutorials are public"
  on public.learning_resources
  for select
  to anon, authenticated
  using (is_published = true and destination = 'tutorial');

drop policy if exists "Approved artisans can view library"
  on public.learning_resources;
create policy "Approved artisans can view library"
  on public.learning_resources
  for select
  to authenticated
  using (
    is_published = true
    and destination = 'library'
    and exists (
      select 1
      from public.profiles profile
      where profile.id = (select auth.uid())
        and profile.role in ('vendor', 'admin')
    )
  );
