drop policy if exists "Buyers can create chat threads" on public.chat_threads;

create policy "Buyers can create chat threads"
  on public.chat_threads for insert
  with check (
    (
      kind = 'buyer_vendor'
      and buyer_id = auth.uid()
      and exists (
        select 1
        from public.shops s
        where s.id = shop_id
      )
    )
    or (
      kind = 'admin_vendor'
      and public.current_user_is_admin()
      and buyer_id = auth.uid()
    )
  );
