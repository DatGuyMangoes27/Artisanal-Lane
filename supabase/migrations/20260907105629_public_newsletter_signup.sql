create table public.newsletter_subscribers (
  email text primary key check (length(email) between 3 and 254 and email = lower(trim(email))),
  subscribed_at timestamptz not null default now(),
  unsubscribed_at timestamptz,
  consent_version text not null default '2026-09',
  source text not null default 'website-public',
  email_verified boolean not null default false,
  unsubscribe_token uuid not null unique default gen_random_uuid(),
  request_hash text not null
);
alter table public.newsletter_subscribers enable row level security;
revoke all on public.newsletter_subscribers from public, anon, authenticated;
grant select, insert, update on public.newsletter_subscribers to service_role;
create index newsletter_signup_rate on public.newsletter_subscribers(request_hash, subscribed_at);
