-- Version aligned with the approved MCP deployment's migration history.
create table public.shop_stories (
 id uuid primary key default gen_random_uuid(),
 shop_id uuid not null references public.shops(id) on delete cascade,
 media_path text not null unique,
 media_type text not null check (media_type in ('image','video')),
 caption text not null default '' check (char_length(caption) <= 500),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default (now() + interval '24 hours'),
 check (expires_at = created_at + interval '24 hours')
);
create index shop_stories_expiry_idx on public.shop_stories(expires_at);
create index shop_stories_shop_created_idx on public.shop_stories(shop_id,created_at);
-- Server time is authoritative. Clients cannot extend or edit a story.
create function public.stamp_shop_story() returns trigger language plpgsql
security invoker set search_path = '' as $$
begin
 if not exists(select 1 from storage.objects o where o.bucket_id='creator-stories' and o.name=new.media_path) then
   raise exception 'Upload story media before publishing';
 end if;
 new.created_at := statement_timestamp();
 new.expires_at := new.created_at + interval '24 hours';
 return new;
end $$;
create trigger stamp_shop_story before insert on public.shop_stories
for each row execute function public.stamp_shop_story();
alter table public.shop_stories enable row level security;
grant select on public.shop_stories to anon,authenticated;
grant insert,delete on public.shop_stories to authenticated;
revoke update on public.shop_stories from anon,authenticated;
create policy stories_live_read on public.shop_stories for select to anon,authenticated
using (expires_at > now() and exists (select 1 from public.shops s where s.id=shop_id
 and ((s.is_active and not s.is_offline) or s.vendor_id=(select auth.uid()))));
create policy stories_owner_insert on public.shop_stories for insert to authenticated
with check (split_part(media_path,'/',1)=(select auth.uid())::text
 and exists(select 1 from public.shops s where s.id=shop_id and s.vendor_id=(select auth.uid())));
create policy stories_owner_delete on public.shop_stories for delete to authenticated
using (exists(select 1 from public.shops s where s.id=shop_id and s.vendor_id=(select auth.uid())));
create table public.shop_story_views (
 user_id uuid not null references public.profiles(id) on delete cascade,
 story_id uuid not null references public.shop_stories(id) on delete cascade,
 viewed_at timestamptz not null default now(), primary key(user_id,story_id)
);
create index shop_story_views_story_idx on public.shop_story_views(story_id);
alter table public.shop_story_views enable row level security;
grant select,insert on public.shop_story_views to authenticated;
create policy story_views_own_read on public.shop_story_views for select to authenticated
using(user_id=(select auth.uid()));
create policy story_views_own_insert on public.shop_story_views for insert to authenticated
with check(user_id=(select auth.uid()) and exists(select 1 from public.shop_stories s where s.id=story_id and s.expires_at>now()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('creator-stories','creator-stories',false,52428800,
 array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']);
create policy story_media_upload on storage.objects for insert to authenticated
with check(bucket_id='creator-stories' and split_part(name,'/',1)=(select auth.uid())::text
 and exists(select 1 from public.shops s where s.vendor_id=(select auth.uid())));
create policy story_media_read on storage.objects for select to anon,authenticated
using(bucket_id='creator-stories' and (split_part(name,'/',1)=(select auth.uid())::text
 or exists(select 1 from public.shop_stories s where s.media_path=name and s.expires_at>now())));
create policy story_media_delete on storage.objects for delete to authenticated
using(bucket_id='creator-stories' and split_part(name,'/',1)=(select auth.uid())::text);
-- Media is downloaded with the viewer JWT, not permanent public/signed URLs.
-- Retention cleanup using the Storage API is a separate deployment task.
