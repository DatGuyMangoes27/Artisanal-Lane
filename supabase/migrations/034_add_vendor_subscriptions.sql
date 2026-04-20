create table if not exists public.vendor_subscriptions (
  vendor_id uuid primary key references public.profiles(id) on delete cascade,
  plan_code text not null default 'artisan-monthly',
  amount numeric(10,2) not null default 349.00,
  currency text not null default 'ZAR',
  status text not null default 'inactive'
    check (status in ('inactive', 'pending', 'active', 'past_due', 'cancelled')),
  checkout_reference text,
  payfast_subscription_id text,
  payfast_token text,
  payfast_payment_id text,
  payfast_email text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  started_at timestamptz,
  last_payment_at timestamptz,
  cancelled_at timestamptz,
  status_reason text,
  last_itn_at timestamptz,
  last_itn_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_vendor_subscriptions_checkout_reference
  on public.vendor_subscriptions(checkout_reference)
  where checkout_reference is not null;

create unique index if not exists idx_vendor_subscriptions_payfast_subscription_id
  on public.vendor_subscriptions(payfast_subscription_id)
  where payfast_subscription_id is not null;

create unique index if not exists idx_vendor_subscriptions_payfast_token
  on public.vendor_subscriptions(payfast_token)
  where payfast_token is not null;

create or replace function public.vendor_subscription_is_active(target_vendor_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.vendor_subscriptions subscriptions
    where subscriptions.vendor_id = target_vendor_id
      and subscriptions.status = 'active'
      and subscriptions.cancelled_at is null
      and (
        subscriptions.current_period_end is null
        or subscriptions.current_period_end > now()
      )
  );
$$;

alter table public.vendor_subscriptions enable row level security;

create policy "Vendors can view own subscriptions"
  on public.vendor_subscriptions for select
  using (auth.uid() = vendor_id);

create policy "Admins can view vendor subscriptions"
  on public.vendor_subscriptions for select
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

create policy "Admins can update vendor subscriptions"
  on public.vendor_subscriptions for update
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  )
  with check (
    exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
  );

create or replace function public.set_vendor_subscriptions_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_vendor_subscriptions_updated_at on public.vendor_subscriptions;

create trigger update_vendor_subscriptions_updated_at
  before update on public.vendor_subscriptions
  for each row execute procedure public.set_vendor_subscriptions_updated_at();

drop policy if exists "vendor_insert_products" on public.products;
create policy "vendor_insert_products" on public.products for insert
  with check (
    shop_id in (select id from public.shops where vendor_id = auth.uid())
    and public.vendor_subscription_is_active(auth.uid())
  );

drop policy if exists "vendor_update_products" on public.products;
create policy "vendor_update_products" on public.products for update
  using (
    shop_id in (select id from public.shops where vendor_id = auth.uid())
    and public.vendor_subscription_is_active(auth.uid())
  )
  with check (
    shop_id in (select id from public.shops where vendor_id = auth.uid())
    and public.vendor_subscription_is_active(auth.uid())
  );
