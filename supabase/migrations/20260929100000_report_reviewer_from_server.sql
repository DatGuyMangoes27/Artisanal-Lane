-- Keep the reviewing admin recorded by the web admin (service role).
create or replace function public.stamp_creator_content_report()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.reporter_id := (select auth.uid());
    new.created_at := statement_timestamp();
    new.details := btrim(new.details);
    new.resolution_notes := '';
    new.status := 'open';
    new.reviewed_by := null;
    new.reviewed_at := null;
    if new.reporter_id is null then
      raise exception 'Sign in to report content';
    end if;
    if exists (select 1 from public.creator_content_reports r
        where r.reporter_id = new.reporter_id and r.target_type = new.target_type
          and r.target_id = new.target_id) then
      return new;
    end if;
    perform pg_advisory_xact_lock(hashtext(new.reporter_id::text));
    if (select count(*) from public.creator_content_reports r
        where r.reporter_id = new.reporter_id
          and r.created_at > statement_timestamp() - interval '1 hour') >= 10 then
      raise exception 'Too many reports. Please try again later';
    end if;
    if new.target_type = 'post' then
      select left(coalesce(p.caption, ''), 4000), s.vendor_id, p.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shop_posts p join public.shops s on s.id = p.shop_id
      where p.id = new.target_id and p.is_published;
    elsif new.target_type = 'comment' then
      select left(c.body, 4000), s.vendor_id, p.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shop_post_comments c
      join public.shop_posts p on p.id = c.post_id
      join public.shops s on s.id = p.shop_id
      where c.id = new.target_id;
    elsif new.target_type = 'story' then
      select left(coalesce(st.caption, ''), 4000), s.vendor_id, st.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shop_stories st join public.shops s on s.id = st.shop_id
      where st.id = new.target_id and st.expires_at > now();
    elsif new.target_type = 'shop' then
      select left(s.name || E'\n' || coalesce(s.bio, ''), 4000), s.vendor_id, s.id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shops s where s.id = new.target_id and s.is_active;
    end if;
    if not found then
      raise exception 'Content is unavailable for reporting';
    end if;
  elsif new.reporter_id is distinct from old.reporter_id
     or new.target_type is distinct from old.target_type
     or new.target_id is distinct from old.target_id
     or new.reason is distinct from old.reason
     or new.details is distinct from old.details
     or new.target_text_snapshot is distinct from old.target_text_snapshot
     or new.target_owner_id is distinct from old.target_owner_id
     or new.target_shop_id is distinct from old.target_shop_id
     or new.created_at is distinct from old.created_at then
    raise exception 'Reports are immutable';
  end if;

  if new.status in ('resolved', 'dismissed') then
    -- The web admin acts through the service role and passes the admin's id.
    new.reviewed_by := case
      when current_user in ('postgres', 'service_role', 'supabase_admin')
        and new.reviewed_by is not null then new.reviewed_by
      else (select auth.uid()) end;
    new.reviewed_at := statement_timestamp();
  else
    new.reviewed_by := null;
    new.reviewed_at := null;
  end if;
  return new;
end;
$$;
