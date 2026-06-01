create table if not exists public.trending_searches (
  id uuid primary key default gen_random_uuid(),
  term text not null,
  sort_order integer default 0,
  is_active boolean default true,
  created_at timestamptz default now()
);

alter table public.trending_searches enable row level security;

drop policy if exists "Public read" on public.trending_searches;
create policy "Public read"
  on public.trending_searches for select
  using (is_active = true);

insert into public.trending_searches (term, sort_order, is_active)
select ranked.title, ranked.sort_order, true
from (
  select
    title,
    row_number() over (
      order by is_featured desc, created_at desc
    )::integer as sort_order
  from public.products
  where is_published = true
    and title is not null
    and btrim(title) <> ''
  limit 8
) ranked
where not exists (
  select 1
  from public.trending_searches existing
  where lower(btrim(existing.term)) = lower(btrim(ranked.title))
);
