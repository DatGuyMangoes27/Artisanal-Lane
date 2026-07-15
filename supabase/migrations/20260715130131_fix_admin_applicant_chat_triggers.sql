-- Allow validated admin-to-applicant chat threads to omit a shop while
-- preserving shop/vendor integrity for every other thread kind.

create or replace function public.set_chat_thread_vendor_id()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  resolved_vendor_id uuid;
begin
  if new.kind = 'admin_applicant' then
    if new.shop_id is not null then
      raise exception 'Admin applicant threads cannot be associated with a shop'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.profiles p
      where p.id = new.vendor_id
        and p.role = 'admin'
    ) then
      raise exception 'Admin applicant threads must be opened by an admin'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.vendor_applications va
      where va.user_id = new.buyer_id
        and va.applicant_account_deleted_at is null
    ) then
      raise exception 'Applicant not found or account has been deleted'
        using errcode = '23514';
    end if;

    return new;
  end if;

  select s.vendor_id
    into resolved_vendor_id
  from public.shops s
  where s.id = new.shop_id;

  if resolved_vendor_id is null then
    raise exception 'Shop not found or has no vendor';
  end if;

  new.vendor_id := resolved_vendor_id;
  return new;
end;
$function$;

create or replace function public.guard_chat_thread()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  buyer_role text;
  buyer_created_at timestamptz;
  paid_order_count integer;
  recent_thread_count integer;
  thread_cap integer;
begin
  -- These conversations are initiated by the admin service flow, not by the
  -- applicant, so they must not count against the applicant's thread limit.
  -- The vendor/admin and applicant relationship is validated by
  -- set_chat_thread_vendor_id().
  if new.kind = 'admin_applicant' then
    return new;
  end if;

  if new.buyer_id is null then
    return new;
  end if;

  select p.role, u.created_at
    into buyer_role, buyer_created_at
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = new.buyer_id;

  if buyer_role in ('admin', 'vendor') then
    return new;
  end if;

  select count(*)
    into paid_order_count
  from public.orders o
  where o.buyer_id = new.buyer_id
    and o.status in ('paid', 'shipped', 'delivered', 'completed');

  if paid_order_count > 0 then
    return new;
  end if;

  thread_cap := case
    when buyer_created_at > now() - interval '24 hours' then 3
    else 10
  end;

  select count(*)
    into recent_thread_count
  from public.chat_threads t
  where t.buyer_id = new.buyer_id
    and t.created_at > now() - interval '24 hours';

  if recent_thread_count >= thread_cap then
    raise exception 'You have started too many new conversations today. Please try again tomorrow.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$function$;
