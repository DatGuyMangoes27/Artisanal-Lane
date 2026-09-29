-- Targeted write hardening. No rows, roles or payment records are changed.
-- Existing public profile reads are deliberately unchanged pending a separate
-- private-profile/public-display-name split and consumer migration.
revoke insert,update,delete,truncate,references,trigger on public.profiles from anon;
revoke delete,truncate,references,trigger on public.profiles from authenticated;
create policy profiles_insert_owner_guard on public.profiles as restrictive
for insert to anon,authenticated with check(id=(select auth.uid()));
create policy profiles_update_owner_guard on public.profiles as restrictive
for update to anon,authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy profiles_delete_server_guard on public.profiles as restrictive
for delete to anon,authenticated using(false);

create function public.guard_profile_privileged_fields() returns trigger
language plpgsql security invoker set search_path='' as $$
declare
  existing_profile jsonb;
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
    select to_jsonb(p) into existing_profile from public.profiles p where p.id=new.id;
    if existing_profile is null and (
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
revoke all on function public.guard_profile_privileged_fields() from public,anon,authenticated;
create trigger guard_profile_privileged_fields before insert or update on public.profiles
for each row execute function public.guard_profile_privileged_fields();
