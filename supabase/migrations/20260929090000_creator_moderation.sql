-- Moderation: user blocking, admin post takedowns and an admin action log.
-- Admin actions run from the web admin with the service role; this migration
-- only adds what the service role and members need. No rows are changed.

-- ── Blocking ──────────────────────────────────────────────────────────────
create table public.user_blocks (
  blocker_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index user_blocks_blocked_idx on public.user_blocks (blocked_id);
alter table public.user_blocks enable row level security;
revoke all on public.user_blocks from public, anon, authenticated;
grant select, insert, delete on public.user_blocks to authenticated;
create policy user_blocks_own on public.user_blocks for all to authenticated
using (blocker_id = (select auth.uid())) with check (blocker_id = (select auth.uid()));

-- True when the caller and `other` have blocked each other in either
-- direction. Only answers about the caller's own relationships.
create function public.is_blocked_with(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select other is not null and (select auth.uid()) is not null and exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = other)
       or (b.blocker_id = other and b.blocked_id = (select auth.uid())));
$$;
revoke all on function public.is_blocked_with(uuid) from public, anon;
grant execute on function public.is_blocked_with(uuid) to authenticated;

-- Blocked people can't comment on each other's posts...
create policy post_comments_block_guard on public.shop_post_comments as restrictive
for insert to authenticated with check (
  not exists (select 1 from public.shop_posts p join public.shops s on s.id = p.shop_id
              where p.id = shop_post_comments.post_id and public.is_blocked_with(s.vendor_id))
);
-- ...open new chats with each other's shops...
create policy chat_threads_block_guard on public.chat_threads as restrictive
for insert to authenticated with check (
  kind <> 'buyer_vendor' or not exists (
    select 1 from public.shops s
    where s.id = chat_threads.shop_id and public.is_blocked_with(s.vendor_id))
);
-- ...or keep messaging in an existing chat.
create policy chat_messages_block_guard on public.chat_messages as restrictive
for insert to authenticated with check (
  not exists (select 1 from public.chat_threads t
              where t.id = chat_messages.thread_id
                and public.is_blocked_with(
                  case when t.buyer_id = (select auth.uid()) then t.vendor_id else t.buyer_id end))
);

-- ── Admin takedowns of posts ──────────────────────────────────────────────
alter table public.shop_posts
  add column removed_at timestamptz,
  add column removed_reason text check (removed_reason is null or char_length(removed_reason) <= 500);

-- Removed posts are visible only to their maker (to see why) and admins.
create policy creator_posts_removed_guard on public.shop_posts as restrictive
for select to anon, authenticated using (
  removed_at is null
  or (select public.current_user_is_admin())
  or exists (select 1 from public.shops s
             where s.id = shop_posts.shop_id and s.vendor_id = (select auth.uid()))
);

-- Makers can't undo a takedown or remove one themselves.
create function public.guard_post_moderation_fields() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if current_user in ('postgres', 'service_role', 'supabase_admin') then return new; end if;
  if tg_op = 'INSERT' then
    if new.removed_at is not null or new.removed_reason is not null then
      raise exception 'Only Artisan Lane can remove posts' using errcode = '42501';
    end if;
  elsif new.removed_at is distinct from old.removed_at
     or new.removed_reason is distinct from old.removed_reason then
    raise exception 'Only Artisan Lane can remove or restore posts' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_post_moderation_fields() from public, anon, authenticated;
create trigger guard_post_moderation_fields before insert or update on public.shop_posts
for each row execute function public.guard_post_moderation_fields();

-- No new likes or comments on removed posts.
create policy post_likes_removed_guard on public.shop_post_likes as restrictive
for insert to authenticated with check (
  exists (select 1 from public.shop_posts p
          where p.id = shop_post_likes.post_id and p.removed_at is null)
);
create policy post_comments_removed_guard on public.shop_post_comments as restrictive
for insert to authenticated with check (
  exists (select 1 from public.shop_posts p
          where p.id = shop_post_comments.post_id and p.removed_at is null)
);

-- ── Admin action log ──────────────────────────────────────────────────────
create table public.moderation_actions (
  id bigint generated always as identity primary key,
  admin_id uuid references public.profiles(id) on delete set null,
  action text not null check (action in (
    'remove_post', 'restore_post', 'delete_comment', 'remove_story',
    'suspend_shop', 'restore_shop', 'suspend_user', 'restore_user',
    'resolve_report', 'dismiss_report')),
  target_type text not null check (target_type in ('post', 'comment', 'story', 'shop', 'user', 'report')),
  target_id uuid not null,
  report_id uuid references public.creator_content_reports(id) on delete set null,
  note text not null default '' check (char_length(note) <= 1000),
  created_at timestamptz not null default now()
);
create index moderation_actions_target_idx on public.moderation_actions (target_type, target_id, created_at desc);
alter table public.moderation_actions enable row level security;
revoke all on public.moderation_actions from public, anon, authenticated;
grant select on public.moderation_actions to authenticated;
create policy moderation_actions_admin_read on public.moderation_actions
for select to authenticated using ((select public.current_user_is_admin()));
