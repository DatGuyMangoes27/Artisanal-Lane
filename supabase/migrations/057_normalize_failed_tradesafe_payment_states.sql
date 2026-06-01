-- Keep failed/refunded TradeSafe callbacks from leaving checkout orders in a
-- pending state. This protects the app even if a callback sends a provider
-- state that was not explicitly handled by the Edge Function mapper.
create or replace function public.normalize_tradesafe_order_payment_state()
returns trigger
language plpgsql
as $$
begin
  if new.payment_provider = 'tradesafe' then
    case upper(coalesce(new.payment_state, ''))
      when 'CANCELLED', 'FAILED', 'EXPIRED', 'REFUNDED', 'DECLINED', 'REJECTED' then
        new.status := 'cancelled';
        new.payment_url := null;
      else
        null;
    end case;
  end if;

  return new;
end;
$$;

drop trigger if exists normalize_tradesafe_order_payment_state_trigger
  on public.orders;

create trigger normalize_tradesafe_order_payment_state_trigger
before insert or update of payment_provider, payment_state
on public.orders
for each row
execute function public.normalize_tradesafe_order_payment_state();

create or replace function public.normalize_tradesafe_escrow_provider_state()
returns trigger
language plpgsql
as $$
begin
  if new.provider = 'tradesafe' then
    case upper(coalesce(new.provider_state, ''))
      when 'REFUNDED' then
        new.status := 'refunded';
      when 'CANCELLED', 'FAILED', 'EXPIRED', 'DECLINED', 'REJECTED' then
        new.status := 'cancelled';
      else
        null;
    end case;
  end if;

  return new;
end;
$$;

drop trigger if exists normalize_tradesafe_escrow_provider_state_trigger
  on public.escrow_transactions;

create trigger normalize_tradesafe_escrow_provider_state_trigger
before insert or update of provider, provider_state
on public.escrow_transactions
for each row
execute function public.normalize_tradesafe_escrow_provider_state();

update public.orders
   set status = 'cancelled',
       payment_url = null,
       updated_at = now()
 where payment_provider = 'tradesafe'
   and upper(coalesce(payment_state, '')) in (
     'CANCELLED',
     'FAILED',
     'EXPIRED',
     'REFUNDED',
     'DECLINED',
     'REJECTED'
   )
   and status = 'pending';

update public.escrow_transactions
   set status = case
     when upper(coalesce(provider_state, '')) = 'REFUNDED' then 'refunded'
     else 'cancelled'
   end
 where provider = 'tradesafe'
   and upper(coalesce(provider_state, '')) in (
     'CANCELLED',
     'FAILED',
     'EXPIRED',
     'REFUNDED',
     'DECLINED',
     'REJECTED'
   )
   and status = 'pending';
