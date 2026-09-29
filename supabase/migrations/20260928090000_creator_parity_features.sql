-- Creator-commerce features from the approved demo: post settings, formats,
-- scheduling, polls, saved posts, muted makers, verified makers, insights,
-- maker reports and story reactions. Additive; existing rows keep today's
-- behaviour (comments on, likes visible, published immediately).

-- ── Post settings, formats and scheduling ─────────────────────────────────
alter table public.shop_posts
  add column comments_enabled boolean not null default true,
  add column hide_like_count boolean not null default false,
  add column scheduled_for timestamptz,
  add column format text not null default 'photo'
    check (format in ('photo', 'video', 'carousel', 'tutorial', 'poll')),
  add column step_captions jsonb not null default '[]'::jsonb
    check (jsonb_typeof(step_captions) = 'array' and jsonb_array_length(step_captions) <= 10),
  add column published_at timestamptz generated always as (coalesce(scheduled_for, created_at)) stored;
create index shop_posts_published_at_idx on public.shop_posts (published_at desc);

-- Scheduled posts stay private to their shop (and admins) until their time.
create policy creator_posts_schedule_guard on public.shop_posts as restrictive
for select to anon, authenticated using (
  scheduled_for is null or scheduled_for <= now()
  or (select public.current_user_is_admin())
  or exists (select 1 from public.shops s
             where s.id = shop_posts.shop_id and s.vendor_id = (select auth.uid()))
);

-- Comments respect the post's setting and schedule.
create policy post_comments_enabled_guard on public.shop_post_comments as restrictive
for insert to authenticated with check (
  exists (select 1 from public.shop_posts p
          where p.id = shop_post_comments.post_id and p.comments_enabled
            and (p.scheduled_for is null or p.scheduled_for <= now()))
);

-- Like counts are hidden from everyone but the shop when the maker asks.
create or replace function public.get_post_engagement(post_ids uuid[])
returns table(post_id uuid, like_count bigint, comment_count bigint, liked_by_me boolean)
language sql stable set search_path = '' as $$
  select p.id,
    case when p.hide_like_count and not exists (
           select 1 from public.shops s
           where s.id = p.shop_id and s.vendor_id = (select auth.uid()))
         then null
         else (select count(*) from public.shop_post_likes l where l.post_id = p.id) end,
    (select count(*) from public.shop_post_comments c where c.post_id = p.id),
    exists (select 1 from public.shop_post_likes l
            where l.post_id = p.id and l.user_id = (select auth.uid()))
  from public.shop_posts p where p.id in (select unnest(post_ids) limit 100);
$$;

-- ── Polls ─────────────────────────────────────────────────────────────────
create table public.post_polls (
  post_id uuid primary key references public.shop_posts(id) on delete cascade,
  question text not null check (char_length(btrim(question)) between 1 and 200),
  options jsonb not null check (jsonb_typeof(options) = 'array'
    and jsonb_array_length(options) between 2 and 4),
  closes_at timestamptz
);
create table public.post_poll_votes (
  post_id uuid not null references public.post_polls(post_id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  option_index int not null check (option_index between 0 and 3),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.post_polls enable row level security;
alter table public.post_poll_votes enable row level security;
revoke all on public.post_polls, public.post_poll_votes from public, anon, authenticated;
grant select on public.post_polls to anon, authenticated;
grant insert, update, delete on public.post_polls to authenticated;
grant select, insert, update, delete on public.post_poll_votes to authenticated;

-- A poll is visible whenever its post is (shop_posts policies apply inside).
create policy post_polls_read on public.post_polls for select to anon, authenticated
using (exists (select 1 from public.shop_posts p where p.id = post_polls.post_id));
create policy post_polls_owner_write on public.post_polls for all to authenticated
using (exists (select 1 from public.shop_posts p join public.shops s on s.id = p.shop_id
               where p.id = post_polls.post_id and s.vendor_id = (select auth.uid())))
with check (exists (select 1 from public.shop_posts p join public.shops s on s.id = p.shop_id
                    where p.id = post_polls.post_id and s.vendor_id = (select auth.uid())));

create policy post_poll_votes_own_read on public.post_poll_votes for select to authenticated
using (user_id = (select auth.uid()));
create policy post_poll_votes_own_delete on public.post_poll_votes for delete to authenticated
using (user_id = (select auth.uid()));
create policy post_poll_votes_cast on public.post_poll_votes for insert to authenticated
with check (
  user_id = (select auth.uid()) and exists (
    select 1 from public.post_polls pp join public.shop_posts p on p.id = pp.post_id
    where pp.post_id = post_poll_votes.post_id and p.is_published
      and (pp.closes_at is null or pp.closes_at > now())
      and post_poll_votes.option_index < jsonb_array_length(pp.options))
);
create policy post_poll_votes_change on public.post_poll_votes for update to authenticated
using (user_id = (select auth.uid()))
with check (
  user_id = (select auth.uid()) and exists (
    select 1 from public.post_polls pp
    where pp.post_id = post_poll_votes.post_id
      and (pp.closes_at is null or pp.closes_at > now())
      and post_poll_votes.option_index < jsonb_array_length(pp.options))
);

-- Aggregate results without exposing who voted for what.
create function public.get_poll_results(p_post_id uuid)
returns table(option_index int, votes bigint, my_vote int)
language sql stable security definer set search_path = '' as $$
  with visible as (
    select pp.options from public.post_polls pp
    join public.shop_posts p on p.id = pp.post_id
    join public.shops s on s.id = p.shop_id
    where pp.post_id = p_post_id and (
      s.vendor_id = (select auth.uid())
      or (p.is_published and s.is_active and not s.is_offline
          and (p.scheduled_for is null or p.scheduled_for <= now())))
  )
  select i::int,
    (select count(*) from public.post_poll_votes v where v.post_id = p_post_id and v.option_index = i),
    (select v.option_index from public.post_poll_votes v
      where v.post_id = p_post_id and v.user_id = (select auth.uid()))
  from visible, generate_series(0, jsonb_array_length(visible.options) - 1) as i;
$$;
revoke all on function public.get_poll_results(uuid) from public;
grant execute on function public.get_poll_results(uuid) to anon, authenticated;

-- ── Saved posts and muted makers (private to each account) ────────────────
create table public.saved_posts (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  post_id uuid not null references public.shop_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create table public.muted_shops (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, shop_id)
);
create index saved_posts_post_idx on public.saved_posts (post_id);
alter table public.saved_posts enable row level security;
alter table public.muted_shops enable row level security;
revoke all on public.saved_posts, public.muted_shops from public, anon, authenticated;
grant select, insert, delete on public.saved_posts, public.muted_shops to authenticated;
create policy saved_posts_own on public.saved_posts for all to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy muted_shops_own on public.muted_shops for all to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ── Verified makers (set by admins through the service role) ──────────────
alter table public.shops add column is_verified boolean not null default false;
create or replace function public.guard_shop_privileged_fields() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin') then return new; end if;
  if new.id is distinct from old.id
    or new.vendor_id is distinct from old.vendor_id
    or new.is_active is distinct from old.is_active
    or new.is_spotlight is distinct from old.is_spotlight
    or new.spotlighted_at is distinct from old.spotlighted_at
    or new.is_verified is distinct from old.is_verified
    or new.created_at is distinct from old.created_at then
    raise exception 'Shop status and ownership changes require a trusted server operation' using errcode = '42501';
  end if;
  return new;
end;
$$;

-- ── Insights: one view per viewer per item per day ────────────────────────
create table public.content_views (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('post', 'product', 'shop')),
  target_id uuid not null,
  shop_id uuid not null references public.shops(id) on delete cascade,
  viewer_key text not null,
  viewed_on date not null default current_date,
  unique (kind, target_id, viewer_key, viewed_on)
);
create index content_views_shop_day_idx on public.content_views (shop_id, viewed_on);
alter table public.content_views enable row level security;
revoke all on public.content_views from public, anon, authenticated;

create function public.record_content_view(p_kind text, p_target uuid, p_session text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_viewer text := coalesce((select auth.uid())::text,
    case when nullif(btrim(p_session), '') is null then null
         else 'guest:' || left(btrim(p_session), 64) end);
  v_shop uuid;
begin
  if v_viewer is null then return; end if;
  if p_kind = 'post' then
    select p.shop_id into v_shop from public.shop_posts p join public.shops s on s.id = p.shop_id
    where p.id = p_target and p.is_published and s.is_active
      and (p.scheduled_for is null or p.scheduled_for <= now());
  elsif p_kind = 'product' then
    select pr.shop_id into v_shop from public.products pr join public.shops s on s.id = pr.shop_id
    where pr.id = p_target and pr.is_published and s.is_active;
  elsif p_kind = 'shop' then
    select s.id into v_shop from public.shops s where s.id = p_target and s.is_active;
  end if;
  -- Makers don't inflate their own numbers.
  if v_shop is null or exists (select 1 from public.shops s
      where s.id = v_shop and s.vendor_id = (select auth.uid())) then
    return;
  end if;
  insert into public.content_views (kind, target_id, shop_id, viewer_key)
  values (p_kind, p_target, v_shop, v_viewer)
  on conflict do nothing;
end;
$$;
revoke all on function public.record_content_view(text, uuid, text) from public;
grant execute on function public.record_content_view(text, uuid, text) to anon, authenticated;

-- The caller's own shop only.
create function public.get_shop_insights(p_days int default 30)
returns jsonb language sql stable security definer set search_path = '' as $$
  with shop as (select id from public.shops where vendor_id = (select auth.uid()) limit 1),
  since as (select (current_date - greatest(1, least(coalesce(p_days, 30), 365)) + 1) as d)
  select case when not exists (select 1 from shop) then null else jsonb_build_object(
    'days', greatest(1, least(coalesce(p_days, 30), 365)),
    'post_views', (select count(*) from public.content_views v, shop, since
                   where v.shop_id = shop.id and v.kind = 'post' and v.viewed_on >= since.d),
    'product_views', (select count(*) from public.content_views v, shop, since
                      where v.shop_id = shop.id and v.kind = 'product' and v.viewed_on >= since.d),
    'profile_views', (select count(*) from public.content_views v, shop, since
                      where v.shop_id = shop.id and v.kind = 'shop' and v.viewed_on >= since.d),
    'likes', (select count(*) from public.shop_post_likes l join public.shop_posts p on p.id = l.post_id, shop, since
              where p.shop_id = shop.id and l.created_at >= since.d),
    'comments', (select count(*) from public.shop_post_comments c join public.shop_posts p on p.id = c.post_id, shop, since
                 where p.shop_id = shop.id and c.created_at >= since.d),
    'saves', (select count(*) from public.saved_posts sp join public.shop_posts p on p.id = sp.post_id, shop, since
              where p.shop_id = shop.id and sp.created_at >= since.d),
    'new_followers', (select count(*) from public.shop_follows f, shop, since
                      where f.shop_id = shop.id and f.created_at >= since.d),
    'followers', (select count(*) from public.shop_follows f, shop where f.shop_id = shop.id),
    'top_posts', coalesce((select jsonb_agg(t order by t.views desc) from (
        select v.target_id as post_id, count(*) as views
        from public.content_views v, shop, since
        where v.shop_id = shop.id and v.kind = 'post' and v.viewed_on >= since.d
        group by v.target_id order by count(*) desc limit 5) t), '[]'::jsonb)
  ) end;
$$;
revoke all on function public.get_shop_insights(int) from public, anon;
grant execute on function public.get_shop_insights(int) to authenticated;

-- ── Maker (shop) reports ──────────────────────────────────────────────────
alter table public.creator_content_reports
  drop constraint creator_content_reports_target_type_check,
  add constraint creator_content_reports_target_type_check
    check (target_type in ('post', 'comment', 'story', 'shop'));

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
    new.reviewed_by := (select auth.uid());
    new.reviewed_at := statement_timestamp();
  else
    new.reviewed_by := null;
    new.reviewed_at := null;
  end if;
  return new;
end;
$$;

drop policy creator_content_reports_insert_visible_target on public.creator_content_reports;
create policy creator_content_reports_insert_visible_target
on public.creator_content_reports for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and case target_type
    when 'post' then exists (select 1 from public.shop_posts p where p.id = target_id and p.is_published)
    when 'comment' then exists (select 1 from public.shop_post_comments c where c.id = target_id)
    when 'story' then exists (select 1 from public.shop_stories s where s.id = target_id and s.expires_at > now())
    when 'shop' then exists (select 1 from public.shops s where s.id = target_id and s.is_active)
    else false
  end
);

-- ── Story reactions ───────────────────────────────────────────────────────
create table public.story_reactions (
  story_id uuid not null references public.shop_stories(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  emoji text not null check (emoji in ('❤️', '🔥', '👏', '😍', '😮')),
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);
alter table public.story_reactions enable row level security;
revoke all on public.story_reactions from public, anon, authenticated;
grant select, insert, update, delete on public.story_reactions to authenticated;
-- Viewers react to stories they can see (shop_stories policies apply inside).
create policy story_reactions_react on public.story_reactions for insert to authenticated
with check (user_id = (select auth.uid())
  and exists (select 1 from public.shop_stories s where s.id = story_reactions.story_id));
create policy story_reactions_change on public.story_reactions for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy story_reactions_remove on public.story_reactions for delete to authenticated
using (user_id = (select auth.uid()));
-- Reactors see their own; the story's maker sees all reactions to it.
create policy story_reactions_read on public.story_reactions for select to authenticated
using (user_id = (select auth.uid()) or exists (
  select 1 from public.shop_stories st join public.shops s on s.id = st.shop_id
  where st.id = story_reactions.story_id and s.vendor_id = (select auth.uid())));
