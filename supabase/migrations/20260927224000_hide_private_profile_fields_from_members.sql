-- Stage 2 of profile privacy. Deploy only after the app and website releases
-- that read private fields through get_my_profile()/get_order_buyer_contacts()
-- are live: older clients select private columns directly and would fail.

-- The profile guard must not read private columns as the calling member.
create or replace function public.guard_profile_privileged_fields() returns trigger
language plpgsql security invoker set search_path='' as $$
declare
  editable text[]:=array['display_name','email','phone','avatar_url',
    'shipping_addresses','vendor_approved_seen_at','updated_at',
    'full_name','company_name','host_bio','city','country'];
begin
  -- Authenticated server/admin operations use the trusted service role. Do not
  -- trust user-editable metadata, or a role supplied in this write, for authority.
  if current_user in ('postgres','service_role','supabase_admin') then return new; end if;
  if current_user <> 'authenticated' or new.id is distinct from (select auth.uid()) then
    raise exception 'Profile writes require the account owner' using errcode='42501';
  end if;
  if tg_op='UPDATE' then
    if (to_jsonb(new)-editable) is distinct from (to_jsonb(old)-editable) then
      raise exception 'Privileged profile fields require a trusted server operation' using errcode='42501';
    end if;
  else
    -- An UPSERT fires INSERT before its UPDATE branch. The UPDATE trigger checks
    -- preserved roles there; do not block approved vendors signing in again.
    if not exists (select 1 from public.profiles p where p.id=new.id) and (
      new.role <> 'buyer' or
      coalesce(to_jsonb(new)->>'admin_role','none') <> 'none' or
      coalesce(to_jsonb(new)->>'user_role','consumer') <> 'consumer' or
      coalesce(to_jsonb(new)->>'onboarding_status','draft') <> 'draft' or
      coalesce(to_jsonb(new)->>'is_verified_host','false') <> 'false' or
      to_jsonb(new)->>'tradesafe_token_id' is not null or
      to_jsonb(new)->>'onboarding_reviewed_at' is not null or
      to_jsonb(new)->>'onboarding_last_note' is not null
    ) then
      raise exception 'New accounts must use unprivileged defaults' using errcode='42501';
    end if;
  end if;
  return new;
end;
$$;

revoke select on public.profiles from authenticated;
grant select (id, display_name, avatar_url, role, created_at, updated_at)
  on public.profiles to authenticated;
