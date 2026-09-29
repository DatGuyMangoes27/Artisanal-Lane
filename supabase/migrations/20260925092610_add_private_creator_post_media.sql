-- Private, signed-only creator-post videos. These restrictive policies remain
-- effective even when historic permissive storage policies are present.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('creator-post-media','creator-post-media',false,52428800,
  array['video/mp4','video/quicktime'])
on conflict (id) do update set public=false,file_size_limit=52428800,
  allowed_mime_types=array['video/mp4','video/quicktime'];

-- Restrictive policies fence this bucket only; other Storage buckets retain
-- their existing policy behavior.
create policy creator_post_media_insert_guard on storage.objects as restrictive
for insert to anon,authenticated with check (
  bucket_id <> 'creator-post-media' or (
  bucket_id='creator-post-media'
  and split_part(name,'/',1)=(select auth.uid())::text
  and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}\.(mp4|mov)$')
  and exists(select 1 from public.shops s where s.vendor_id=(select auth.uid()))
  )
);

create policy creator_post_media_select_guard on storage.objects as restrictive
for select to anon,authenticated using (
  bucket_id <> 'creator-post-media' or (bucket_id='creator-post-media' and (
    split_part(name,'/',1)=(select auth.uid())::text or exists(
      select 1 from public.shop_posts p join public.shops s on s.id=p.shop_id
      where p.is_published and s.is_active and not s.is_offline
      and s.vendor_id::text=split_part(name,'/',1)
      and p.media_urls @> jsonb_build_array('artisan-post://' || name)
    )
  ))
);

create policy creator_post_media_delete_guard on storage.objects as restrictive
for delete to anon,authenticated using (
  bucket_id <> 'creator-post-media' or (bucket_id='creator-post-media'
  and split_part(name,'/',1)=(select auth.uid())::text
  )
);

-- Fence legacy UPDATE/ALL policies: creator uploads are immutable.
create policy creator_post_media_update_guard on storage.objects as restrictive
for update to anon,authenticated using (bucket_id <> 'creator-post-media')
with check (bucket_id <> 'creator-post-media');

-- These permissive policies make the feature work even when no old broad
-- Storage policy exists. The restrictive policies above remain the final fence.
create policy creator_post_media_upload on storage.objects for insert to authenticated
with check (bucket_id='creator-post-media'
 and split_part(name,'/',1)=(select auth.uid())::text
 and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}\.(mp4|mov)$')
 and exists(select 1 from public.shops s where s.vendor_id=(select auth.uid())));
create policy creator_post_media_read on storage.objects for select to anon,authenticated
using (bucket_id='creator-post-media' and (
 split_part(name,'/',1)=(select auth.uid())::text or exists(
   select 1 from public.shop_posts p join public.shops s on s.id=p.shop_id
   where p.is_published and s.is_active and not s.is_offline
   and s.vendor_id::text=split_part(name,'/',1)
   and p.media_urls @> jsonb_build_array('artisan-post://' || name)
 )));
create policy creator_post_media_delete on storage.objects for delete to authenticated
using (bucket_id='creator-post-media' and split_part(name,'/',1)=(select auth.uid())::text);
