-- ============================================================
-- Push notification device tokens
-- ============================================================

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios', 'web', 'unknown')),
  device_id text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (token)
);

create index if not exists idx_user_push_tokens_user_id
  on public.user_push_tokens (user_id)
  where revoked_at is null;

create index if not exists idx_user_push_tokens_token
  on public.user_push_tokens (token);

alter table public.user_push_tokens enable row level security;

drop policy if exists "Users can view their own push tokens" on public.user_push_tokens;
create policy "Users can view their own push tokens"
  on public.user_push_tokens for select
  using (user_id = auth.uid());

drop policy if exists "Users can insert their own push tokens" on public.user_push_tokens;
create policy "Users can insert their own push tokens"
  on public.user_push_tokens for insert
  with check (user_id = auth.uid());

drop policy if exists "Users can update their own push tokens" on public.user_push_tokens;
create policy "Users can update their own push tokens"
  on public.user_push_tokens for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop trigger if exists update_user_push_tokens_updated_at on public.user_push_tokens;
create trigger update_user_push_tokens_updated_at
  before update on public.user_push_tokens
  for each row execute function public.update_updated_at_column();

create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_device_id text default null
)
returns public.user_push_tokens
language plpgsql
security definer
set search_path = public
as $$
declare
  saved_token public.user_push_tokens;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'Push token is required';
  end if;

  insert into public.user_push_tokens (
    user_id,
    token,
    platform,
    device_id,
    last_seen_at,
    revoked_at
  )
  values (
    auth.uid(),
    trim(p_token),
    coalesce(nullif(trim(p_platform), ''), 'unknown'),
    nullif(trim(coalesce(p_device_id, '')), ''),
    now(),
    null
  )
  on conflict (token) do update
  set
    user_id = excluded.user_id,
    platform = excluded.platform,
    device_id = excluded.device_id,
    last_seen_at = now(),
    revoked_at = null,
    updated_at = now()
  returning * into saved_token;

  return saved_token;
end;
$$;

create or replace function public.revoke_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.user_push_tokens
  set revoked_at = now(), updated_at = now()
  where token = trim(p_token)
    and user_id = auth.uid();
end;
$$;

grant execute on function public.register_push_token(text, text, text) to authenticated;
grant execute on function public.revoke_push_token(text) to authenticated;
