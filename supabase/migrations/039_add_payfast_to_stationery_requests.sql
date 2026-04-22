alter table public.stationery_requests
  add column if not exists amount numeric(10,2) not null default 0,
  add column if not exists currency text not null default 'ZAR',
  add column if not exists checkout_reference text,
  add column if not exists payment_reference text,
  add column if not exists payfast_payment_id text,
  add column if not exists payfast_email text,
  add column if not exists paid_at timestamptz,
  add column if not exists last_itn_at timestamptz,
  add column if not exists last_itn_payload jsonb,
  add column if not exists status_reason text;

update public.stationery_requests
set amount = coalesce((
  select sum(
    case coalesce(item->>'key', '')
      when 'gift_tag' then 7
      when 'wrap_sheet' then 15
      when 'sticker' then 4
      else 0
    end * greatest(coalesce((item->>'quantity')::integer, 0), 0)
  )
  from jsonb_array_elements(coalesce(items, '[]'::jsonb)) as item
), 0)
where amount = 0;

alter table public.stationery_requests
  drop constraint if exists stationery_requests_status_check;

update public.stationery_requests
set status = 'awaiting_payment'
where status = 'pending';

alter table public.stationery_requests
  add constraint stationery_requests_status_check check (
    status in (
      'awaiting_payment',
      'paid',
      'processing',
      'shipped',
      'delivered',
      'cancelled'
    )
  );

alter table public.stationery_requests
  alter column status set default 'awaiting_payment';

create unique index if not exists idx_stationery_requests_checkout_reference
  on public.stationery_requests(checkout_reference)
  where checkout_reference is not null;

create unique index if not exists idx_stationery_requests_payment_reference
  on public.stationery_requests(payment_reference)
  where payment_reference is not null;

create unique index if not exists idx_stationery_requests_payfast_payment_id
  on public.stationery_requests(payfast_payment_id)
  where payfast_payment_id is not null;
