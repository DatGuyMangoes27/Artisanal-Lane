-- ============================================================
-- Learning hub (podcasts, video tutorials, articles)
-- ============================================================
-- An admin-curated library of learning content surfaced on the public
-- website at /learn. Each item links out to an external podcast / video /
-- article and carries an uploaded thumbnail. Website-only feature.

create table if not exists public.learning_resources (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'article'
    check (type in ('podcast', 'video', 'article')),
  title text not null,
  description text,
  content_url text not null,
  thumbnail_url text,
  author text,
  duration_label text,
  is_published boolean not null default true,
  is_featured boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_learning_resources_published
  on public.learning_resources(type, sort_order, created_at)
  where is_published = true;

alter table public.learning_resources enable row level security;

drop policy if exists "Published learning resources are public"
  on public.learning_resources;
create policy "Published learning resources are public"
  on public.learning_resources
  for select
  using (is_published = true);

drop policy if exists "Admins manage learning resources"
  on public.learning_resources;
create policy "Admins manage learning resources"
  on public.learning_resources
  for all
  using (public.current_user_is_admin())
  with check (public.current_user_is_admin());

create trigger learning_resources_updated_at
  before update on public.learning_resources
  for each row
  execute function public.update_updated_at_column();

-- Public bucket for learning thumbnails (admins upload via service role).
insert into storage.buckets (id, name, public)
values ('learning-assets', 'learning-assets', true)
on conflict (id) do nothing;
