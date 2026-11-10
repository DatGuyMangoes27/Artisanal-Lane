-- Buyers who agreed at checkout to hear from Artisan Lane (news, offers and
-- follow-ups by email, SMS or WhatsApp). One row per account. Only the
-- buyer's own opt-in creates a row; unticking (or unsubscribing) sets
-- unsubscribed_at and keeps the record of consent. Read by admins through
-- the service role (CSV export); buyers can read their own row.

create table if not exists public.marketing_contacts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  phone text,
  display_name text,
  channels text[] not null default array['email','sms','whatsapp'],
  consent_text text not null,
  consent_version text not null,
  source text not null,
  consented_at timestamptz not null default now(),
  unsubscribed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.marketing_contacts enable row level security;

drop policy if exists marketing_contacts_read_own on public.marketing_contacts;
create policy marketing_contacts_read_own on public.marketing_contacts
  for select to authenticated using (user_id = (select auth.uid()));

-- Records the signed-in buyer's choice. Email and name come from their
-- profile; the phone is the one they typed at checkout.
create or replace function public.set_marketing_consent(
  p_opt_in boolean,
  p_phone text,
  p_source text,
  p_consent_text text,
  p_consent_version text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email text;
  v_name text;
  v_phone text := nullif(left(trim(coalesce(p_phone, '')), 40), '');
begin
  if v_user is null then
    raise exception 'Sign in to choose marketing updates.' using errcode = '42501';
  end if;
  if p_source not in ('web-checkout', 'app-checkout') then
    raise exception 'Unknown consent source.' using errcode = '22023';
  end if;

  if not p_opt_in then
    update public.marketing_contacts
       set unsubscribed_at = coalesce(unsubscribed_at, now()), updated_at = now()
     where user_id = v_user;
    return;
  end if;

  select email, display_name into v_email, v_name
    from public.profiles where id = v_user;

  insert into public.marketing_contacts as mc (
    user_id, email, phone, display_name, consent_text, consent_version, source
  ) values (
    v_user, v_email, v_phone, v_name,
    left(coalesce(p_consent_text, ''), 1000),
    left(coalesce(p_consent_version, ''), 40),
    p_source
  )
  on conflict (user_id) do update set
    email = excluded.email,
    phone = coalesce(excluded.phone, mc.phone),
    display_name = excluded.display_name,
    consent_text = excluded.consent_text,
    consent_version = excluded.consent_version,
    source = excluded.source,
    consented_at = case when mc.unsubscribed_at is null then mc.consented_at else now() end,
    unsubscribed_at = null,
    updated_at = now();
end;
$$;

revoke all on function public.set_marketing_consent(boolean, text, text, text, text) from public, anon;
grant execute on function public.set_marketing_consent(boolean, text, text, text, text) to authenticated;
