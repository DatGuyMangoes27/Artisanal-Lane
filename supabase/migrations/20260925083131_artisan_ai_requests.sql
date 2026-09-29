-- Internal AI pilot. No client writes; server must explicitly enable paid work.
-- Remote migration version aligned after approved deployment on 2026-09-25.
create table public.artisan_ai_requests (
 id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 shop_id uuid not null references public.shops(id) on delete cascade,
 operation text not null check(operation in ('listing','image')),
 payload_hash text not null check(length(payload_hash)=64),
 status text not null default 'pending' check(status in ('pending','succeeded','failed')),
 result jsonb, created_at timestamptz not null default now()
);
create index artisan_ai_requests_quota_idx on public.artisan_ai_requests(operation,created_at,user_id);
alter table public.artisan_ai_requests enable row level security;
revoke all on public.artisan_ai_requests from public,anon,authenticated;
grant select on public.artisan_ai_requests to authenticated;
grant select,insert,update on public.artisan_ai_requests to service_role;
create policy ai_requests_own_read on public.artisan_ai_requests for select to authenticated
 using(user_id=(select auth.uid()));
create function public.reserve_artisan_ai_request(p_id uuid,p_user uuid,p_shop uuid,p_operation text,p_hash text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare existing public.artisan_ai_requests; total_count bigint; own_count bigint;
begin
 perform pg_catalog.pg_advisory_xact_lock(817260923);
 if not exists(select 1 from public.shops where id=p_shop and vendor_id=p_user) then raise exception 'shop_not_owned'; end if;
 select * into existing from public.artisan_ai_requests where id=p_id;
 if found then
  if existing.user_id<>p_user or existing.shop_id<>p_shop or existing.operation<>p_operation or existing.payload_hash<>p_hash then raise exception 'request_conflict'; end if;
  return jsonb_build_object('reserved',false,'status',existing.status,'result',existing.result);
 end if;
 if p_operation not in ('listing','image') then raise exception 'invalid_operation'; end if;
 select count(*),count(*) filter(where user_id=p_user) into total_count,own_count from public.artisan_ai_requests
 where operation=p_operation and created_at>=now()-interval '24 hours';
 if total_count >= (case when p_operation='image' then 25 else 100 end)
 or own_count >= (case when p_operation='image' then 5 else 20 end) then raise exception 'quota_exceeded'; end if;
 insert into public.artisan_ai_requests(id,user_id,shop_id,operation,payload_hash) values(p_id,p_user,p_shop,p_operation,p_hash);
 return jsonb_build_object('reserved',true,'status','pending');
end $$;
revoke all on function public.reserve_artisan_ai_request(uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.reserve_artisan_ai_request(uuid,uuid,uuid,text,text) to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('artisan-ai-results','artisan-ai-results',false,20971520,array['image/png']);
create policy ai_results_own_read on storage.objects for select to authenticated
 using(bucket_id='artisan-ai-results' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Fence this bucket even if older project policies are overly permissive.
create policy ai_results_read_guard on storage.objects as restrictive for select to anon,authenticated
 using(bucket_id<>'artisan-ai-results' or (storage.foldername(name))[1]=(select auth.uid())::text);
create policy ai_results_insert_guard on storage.objects as restrictive for insert to anon,authenticated
 with check(bucket_id<>'artisan-ai-results');
create policy ai_results_update_guard on storage.objects as restrictive for update to anon,authenticated
 using(bucket_id<>'artisan-ai-results') with check(bucket_id<>'artisan-ai-results');
create policy ai_results_delete_guard on storage.objects as restrictive for delete to anon,authenticated
 using(bucket_id<>'artisan-ai-results');
