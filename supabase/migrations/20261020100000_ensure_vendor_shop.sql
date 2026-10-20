-- Approved artisans without a shop.
--
-- Until the web admin's approval was fixed, approving an application ignored
-- errors, so many artisans got the vendor role but no shops row. Every seller
-- screen needs that row ("No shop found"), and nothing could create it.
--
-- create_vendor_shop_from_application(vendor) does what approval does: one
-- active shop named after the artisan's approved application. It is internal
-- (service role only). ensure_vendor_shop() lets a signed-in artisan repair
-- only their own missing shop; the apps call it when the shop is missing.
-- shops.vendor_id is unique, so neither can create a second shop.

create or replace function public.create_vendor_shop_from_application(target_vendor uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  existing_id uuid;
  app record;
  shop_name text;
  base_slug text;
  new_id uuid;
  attempt int := 0;
begin
  select s.id into existing_id from public.shops s where s.vendor_id = target_vendor;
  if existing_id is not null then
    return existing_id;
  end if;

  if not exists (
    select 1 from public.profiles p where p.id = target_vendor and p.role = 'vendor'
  ) then
    raise exception 'Only approved artisans have a shop' using errcode = '42501';
  end if;

  select a.business_name, a.location into app
  from public.vendor_applications a
  where (a.user_id = target_vendor or a.applicant_user_id_snapshot = target_vendor)
    and a.status = 'approved'
  order by a.created_at desc
  limit 1;

  shop_name := nullif(btrim(coalesce(app.business_name, '')), '');
  if shop_name is null then
    select nullif(btrim(coalesce(p.display_name, '')), '') into shop_name
    from public.profiles p where p.id = target_vendor;
  end if;
  shop_name := left(coalesce(shop_name, 'My shop'), 80);

  base_slug := left(trim(both '-' from regexp_replace(lower(shop_name), '[^a-z0-9]+', '-', 'g')), 40);
  if base_slug = '' then
    base_slug := 'shop';
  end if;

  loop
    attempt := attempt + 1;
    begin
      insert into public.shops (vendor_id, name, slug, bio, location, is_active)
      values (
        target_vendor,
        shop_name,
        base_slug || '-' || lpad((floor(random() * 1000000))::int::text, 6, '0'),
        'Welcome to ' || shop_name || '.',
        nullif(btrim(coalesce(app.location, '')), ''),
        true
      )
      returning id into new_id;
      return new_id;
    exception
      when unique_violation then
        -- Another request created the shop first, or the random slug clashed.
        select s.id into existing_id from public.shops s where s.vendor_id = target_vendor;
        if existing_id is not null then
          return existing_id;
        end if;
        if attempt >= 5 then
          raise;
        end if;
    end;
  end loop;
end;
$$;

revoke all on function public.create_vendor_shop_from_application(uuid) from public, anon, authenticated;
grant execute on function public.create_vendor_shop_from_application(uuid) to service_role;

create or replace function public.ensure_vendor_shop()
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in to set up your shop' using errcode = '42501';
  end if;
  return public.create_vendor_shop_from_application((select auth.uid()));
end;
$$;

revoke all on function public.ensure_vendor_shop() from public, anon;
grant execute on function public.ensure_vendor_shop() to authenticated;
