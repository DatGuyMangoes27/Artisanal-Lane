drop policy if exists "Dispute participants can view conversations" on public.dispute_conversations;

create policy "Dispute participants can view conversations"
  on public.dispute_conversations for select
  using (
    buyer_id = auth.uid()
    or seller_id = auth.uid()
    or exists (
      select 1
      from public.profiles profile
      where profile.id = auth.uid()
        and profile.role = 'admin'
    )
  );
