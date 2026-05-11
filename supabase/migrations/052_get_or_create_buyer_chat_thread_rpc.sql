create or replace function public.get_or_create_buyer_chat_thread(
  shop_uuid uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_buyer_id uuid := auth.uid();
  resolved_thread_id uuid;
begin
  if current_buyer_id is null then
    raise exception 'You must be signed in to message this shop.';
  end if;

  insert into public.chat_threads (shop_id, buyer_id)
  values (shop_uuid, current_buyer_id)
  on conflict (shop_id, buyer_id) do update
    set updated_at = public.chat_threads.updated_at
  returning id into resolved_thread_id;

  return resolved_thread_id;
end;
$$;

grant execute on function public.get_or_create_buyer_chat_thread(uuid)
  to authenticated;
