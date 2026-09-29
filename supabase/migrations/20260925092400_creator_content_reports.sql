-- Private creator-content reports. This migration deliberately records reports
-- only; it never hides or deletes creator content automatically.
create table public.creator_content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'comment', 'story')),
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'harassment', 'hate_or_abuse', 'sexual_content', 'intellectual_property', 'other')),
  details text not null default '' check (char_length(btrim(details)) <= 1000),
  target_text_snapshot text not null default '',
  target_owner_id uuid,
  target_shop_id uuid,
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  resolution_notes text not null default '' check (char_length(btrim(resolution_notes)) <= 1000),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  unique (reporter_id, target_type, target_id)
);

create index creator_content_reports_admin_queue_idx
  on public.creator_content_reports (status, created_at desc);
create index creator_content_reports_reporter_created_idx
  on public.creator_content_reports (reporter_id, created_at desc);

create function public.stamp_creator_content_report()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
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
    -- A retry can race an earlier committed insert. Let the uniqueness
    -- constraint preserve the single receipt without applying the rate cap.
    if exists (select 1 from public.creator_content_reports r
        where r.reporter_id = new.reporter_id
          and r.target_type = new.target_type
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
    new.reviewed_by := (select auth.uid());
    new.reviewed_at := statement_timestamp();
  else
    new.reviewed_by := null;
    new.reviewed_at := null;
  end if;
  return new;
end;
$$;

create trigger stamp_creator_content_report
before insert or update on public.creator_content_reports
for each row execute function public.stamp_creator_content_report();

alter table public.creator_content_reports enable row level security;
revoke all on public.creator_content_reports from public, anon, authenticated;
grant select, insert on public.creator_content_reports to authenticated;
grant update(status, resolution_notes) on public.creator_content_reports to authenticated;
revoke all on function public.stamp_creator_content_report() from public, anon;
grant execute on function public.stamp_creator_content_report() to authenticated;

create policy creator_content_reports_insert_visible_target
on public.creator_content_reports for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and case target_type
    when 'post' then exists (select 1 from public.shop_posts p where p.id = target_id and p.is_published)
    when 'comment' then exists (select 1 from public.shop_post_comments c where c.id = target_id)
    when 'story' then exists (select 1 from public.shop_stories s where s.id = target_id and s.expires_at > now())
    else false
  end
);

create policy creator_content_reports_reporter_receipts
on public.creator_content_reports for select to authenticated
using (reporter_id = (select auth.uid()));

create policy creator_content_reports_admin_review
on public.creator_content_reports for select to authenticated
using ((select public.current_user_is_admin()));

create policy creator_content_reports_admin_resolve
on public.creator_content_reports for update to authenticated
using ((select public.current_user_is_admin()))
with check ((select public.current_user_is_admin()));
