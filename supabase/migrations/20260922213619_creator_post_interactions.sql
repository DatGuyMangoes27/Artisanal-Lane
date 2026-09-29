-- Version aligned with the approved deployment's migration history.
-- Restrictive guards neutralise older permissive demo policies without removing
-- unrelated policies. Admin moderation continues through the existing helper.
create policy creator_posts_read_guard on public.shop_posts as restrictive for select to anon,authenticated
using ((select public.current_user_is_admin()) or exists(select 1 from public.shops s where s.id=shop_id
 and (s.vendor_id=(select auth.uid()) or (is_published and s.is_active and not s.is_offline))));
create policy creator_posts_insert_guard on public.shop_posts as restrictive for insert to anon,authenticated
with check ((select public.current_user_is_admin()) or exists(select 1 from public.shops s where s.id=shop_id and s.vendor_id=(select auth.uid())));
create policy creator_posts_update_guard on public.shop_posts as restrictive for update to anon,authenticated
using ((select public.current_user_is_admin()) or exists(select 1 from public.shops s where s.id=shop_id and s.vendor_id=(select auth.uid())))
with check ((select public.current_user_is_admin()) or exists(select 1 from public.shops s where s.id=shop_id and s.vendor_id=(select auth.uid())));
create policy creator_posts_delete_guard on public.shop_posts as restrictive for delete to anon,authenticated
using ((select public.current_user_is_admin()) or exists(select 1 from public.shops s where s.id=shop_id and s.vendor_id=(select auth.uid())));
create policy creator_follows_insert_guard on public.shop_follows as restrictive for insert to anon,authenticated
with check (user_id=(select auth.uid()));
create policy creator_follows_delete_guard on public.shop_follows as restrictive for delete to anon,authenticated
using (user_id=(select auth.uid()));
create policy creator_follows_update_guard on public.shop_follows as restrictive for update to anon,authenticated
using (false) with check(false);

alter table public.shop_posts add column product_ids uuid[] not null default '{}';
alter table public.shop_posts add constraint post_product_limit check(cardinality(product_ids)<=5);
create function public.validate_post_product_links() returns trigger language plpgsql
security invoker set search_path='' as $$
begin
 if tg_op='UPDATE' then
   if new.product_ids=old.product_ids and new.shop_id=old.shop_id then return new; end if;
 end if;
 if cardinality(new.product_ids)<>(select count(distinct id) from unnest(new.product_ids) as id) then
   raise exception 'Product links must be unique and non-null';
 end if;
 if exists(select 1 from unnest(new.product_ids) as tagged(product_id) where not exists(
   select 1 from public.products p where p.id=tagged.product_id and p.shop_id=new.shop_id and p.is_published)) then
   raise exception 'Tag only published products from this shop';
 end if;
 return new;
end $$;
create trigger validate_post_product_links before insert or update on public.shop_posts
for each row execute function public.validate_post_product_links();

create table public.shop_post_likes (
 post_id uuid not null references public.shop_posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(post_id,user_id)
);
create index shop_post_likes_user_idx on public.shop_post_likes(user_id);
alter table public.shop_post_likes enable row level security;
grant select on public.shop_post_likes to anon,authenticated;
grant insert,delete on public.shop_post_likes to authenticated;
create policy post_likes_read on public.shop_post_likes for select to anon,authenticated
using(exists(select 1 from public.shop_posts p where p.id=post_id));
create policy post_likes_insert on public.shop_post_likes for insert to authenticated
with check(user_id=(select auth.uid()) and exists(select 1 from public.shop_posts p where p.id=post_id and p.is_published));
create policy post_likes_delete on public.shop_post_likes for delete to authenticated
using(user_id=(select auth.uid()));

create table public.shop_post_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.shop_posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(btrim(body)) between 1 and 1000),
 author_name text not null default 'Member',
 created_at timestamptz not null default now(),
 edited boolean not null default false
);
create index shop_post_comments_page_idx on public.shop_post_comments(post_id,created_at desc,id desc);
create index shop_post_comments_user_idx on public.shop_post_comments(user_id);
alter table public.shop_post_comments enable row level security;
grant select on public.shop_post_comments to anon,authenticated;
grant insert,delete on public.shop_post_comments to authenticated;
revoke update on public.shop_post_comments from anon,authenticated;
grant update(body) on public.shop_post_comments to authenticated;
create function public.stamp_post_comment() returns trigger language plpgsql
security invoker set search_path='' as $$
begin
 new.body:=btrim(new.body);
 if tg_op='INSERT' then
   new.created_at:=statement_timestamp(); new.edited:=false;
   select coalesce(nullif(btrim(display_name),''),'Member') into new.author_name
     from public.profiles where id=(select auth.uid());
   new.author_name:=coalesce(new.author_name,'Member');
 else
   new.edited:=true;
 end if;
 return new;
end $$;
create trigger stamp_post_comment before insert or update on public.shop_post_comments
for each row execute function public.stamp_post_comment();
create policy post_comments_read on public.shop_post_comments for select to anon,authenticated
using(exists(select 1 from public.shop_posts p where p.id=post_id));
create policy post_comments_insert on public.shop_post_comments for insert to authenticated
with check(user_id=(select auth.uid()) and exists(select 1 from public.shop_posts p where p.id=post_id and p.is_published));
create policy post_comments_update on public.shop_post_comments for update to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy post_comments_delete on public.shop_post_comments for delete to authenticated
using(user_id=(select auth.uid()) or (select public.current_user_is_admin()) or exists(
 select 1 from public.shop_posts p join public.shops s on s.id=p.shop_id
 where p.id=post_id and s.vendor_id=(select auth.uid())));

create function public.get_post_engagement(post_ids uuid[])
returns table(post_id uuid,like_count bigint,comment_count bigint,liked_by_me boolean)
language sql stable security invoker set search_path='' as $$
 select p.id,
 (select count(*) from public.shop_post_likes l where l.post_id=p.id),
 (select count(*) from public.shop_post_comments c where c.post_id=p.id),
 exists(select 1 from public.shop_post_likes l where l.post_id=p.id and l.user_id=(select auth.uid()))
 from public.shop_posts p where p.id in(select unnest(post_ids) limit 100);
$$;
revoke execute on function public.get_post_engagement(uuid[]) from public;
grant execute on function public.get_post_engagement(uuid[]) to anon,authenticated;
