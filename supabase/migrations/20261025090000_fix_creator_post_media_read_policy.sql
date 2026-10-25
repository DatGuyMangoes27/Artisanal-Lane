-- Fix: creator post videos could only be read (signed) by the maker who
-- uploaded them. In 20260925092610 the "published post" branch of both SELECT
-- policies used an unqualified `name` inside a subquery that joins
-- public.shops, so Postgres resolved it to shops.name (the shop's display
-- name) instead of storage.objects.name. The check therefore never matched and
-- every buyer got "Object not found" from createSignedUrl, leaving feed videos
-- stuck on the "Watch video" placeholder. Qualify the column as objects.name.

drop policy if exists creator_post_media_select_guard on storage.objects;
create policy creator_post_media_select_guard on storage.objects as restrictive
for select to anon,authenticated using (
  bucket_id <> 'creator-post-media' or (bucket_id='creator-post-media' and (
    split_part(objects.name,'/',1)=(select auth.uid())::text or exists(
      select 1 from public.shop_posts p join public.shops s on s.id=p.shop_id
      where p.is_published and p.removed_at is null
      and s.is_publicly_listed and not s.is_offline
      and s.vendor_id::text=split_part(objects.name,'/',1)
      and p.media_urls @> jsonb_build_array('artisan-post://' || objects.name)
    )
  ))
);

drop policy if exists creator_post_media_read on storage.objects;
create policy creator_post_media_read on storage.objects for select to anon,authenticated
using (bucket_id='creator-post-media' and (
 split_part(objects.name,'/',1)=(select auth.uid())::text or exists(
   select 1 from public.shop_posts p join public.shops s on s.id=p.shop_id
   where p.is_published and p.removed_at is null
   and s.is_publicly_listed and not s.is_offline
   and s.vendor_id::text=split_part(objects.name,'/',1)
   and p.media_urls @> jsonb_build_array('artisan-post://' || objects.name)
 )));
