-- Anti-phishing guards for chat, prompted by a scam account messaging vendors
-- with fake "your item was purchased" payment-verification links.
--
-- 1. Buyers with no completed purchase history may not send links in chat.
-- 2. New accounts are rate-limited on messages and new threads.
-- Vendors and admins are unaffected (vendors legitimately share social links).

create or replace function public.chat_message_contains_link(body text)
returns boolean
language sql
immutable
as $$
  select body ~* '(https?://|www\.|\m[a-z0-9-]+\.(com|net|org|info|biz|xyz|top|rest|icu|club|online|site|live|store|shop|link|click|monster|quest|cyou|bond|sbs|lol|cfd)(/|\s|$))';
$$;

create or replace function public.guard_chat_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  sender_role text;
  sender_created_at timestamptz;
  paid_order_count integer;
  recent_message_count integer;
begin
  -- System / service-role inserts without a sender pass through.
  if new.sender_id is null then
    return new;
  end if;

  select p.role, u.created_at
    into sender_role, sender_created_at
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = new.sender_id;

  if sender_role in ('admin', 'vendor') then
    return new;
  end if;

  -- Rate limit: at most 20 chat messages per 10 minutes for buyers,
  -- and at most 10 per 10 minutes during an account's first 24 hours.
  select count(*)
    into recent_message_count
  from public.chat_messages m
  where m.sender_id = new.sender_id
    and m.created_at > now() - interval '10 minutes';

  if recent_message_count >= 20
     or (sender_created_at > now() - interval '24 hours' and recent_message_count >= 10) then
    raise exception 'You are sending messages too quickly. Please wait a few minutes and try again.'
      using errcode = 'P0001';
  end if;

  -- Link filter: buyers may only send links once they have made a purchase.
  if new.body is not null and public.chat_message_contains_link(new.body) then
    select count(*)
      into paid_order_count
    from public.orders o
    where o.buyer_id = new.sender_id
      and o.status in ('paid', 'shipped', 'delivered', 'completed');

    if paid_order_count = 0 then
      raise exception 'Links cannot be sent in chat before your first purchase. Please remove the link and try again.'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists guard_chat_message on public.chat_messages;
create trigger guard_chat_message
  before insert on public.chat_messages
  for each row execute procedure public.guard_chat_message();

create or replace function public.guard_chat_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  buyer_role text;
  buyer_created_at timestamptz;
  paid_order_count integer;
  recent_thread_count integer;
  thread_cap integer;
begin
  if new.buyer_id is null then
    return new;
  end if;

  select p.role, u.created_at
    into buyer_role, buyer_created_at
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = new.buyer_id;

  if buyer_role in ('admin', 'vendor') then
    return new;
  end if;

  select count(*)
    into paid_order_count
  from public.orders o
  where o.buyer_id = new.buyer_id
    and o.status in ('paid', 'shipped', 'delivered', 'completed');

  -- Accounts younger than 24h with no purchases: 3 new threads per day.
  -- Older accounts with no purchases: 10 per day. Paying customers: unlimited.
  if paid_order_count > 0 then
    return new;
  end if;

  thread_cap := case
    when buyer_created_at > now() - interval '24 hours' then 3
    else 10
  end;

  select count(*)
    into recent_thread_count
  from public.chat_threads t
  where t.buyer_id = new.buyer_id
    and t.created_at > now() - interval '24 hours';

  if recent_thread_count >= thread_cap then
    raise exception 'You have started too many new conversations today. Please try again tomorrow.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_chat_thread on public.chat_threads;
create trigger guard_chat_thread
  before insert on public.chat_threads
  for each row execute procedure public.guard_chat_thread();
