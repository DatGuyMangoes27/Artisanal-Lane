create or replace function public.is_dispute_conversation_participant(conversation_uuid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.dispute_conversations conversation
    where conversation.id = conversation_uuid
      and (
        conversation.buyer_id = auth.uid()
        or conversation.seller_id = auth.uid()
      )
  )
  or exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role = 'admin'
  );
$$;
