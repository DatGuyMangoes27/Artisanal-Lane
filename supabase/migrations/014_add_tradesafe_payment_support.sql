alter table profiles
  add column if not exists tradesafe_token_id text;

alter table orders
  add column if not exists payment_provider text not null default 'tradesafe',
  add column if not exists payment_state text not null default 'created',
  add column if not exists payment_reference text,
  add column if not exists payment_url text,
  add column if not exists tradesafe_transaction_id text,
  add column if not exists tradesafe_allocation_id text,
  add column if not exists paid_at timestamptz;

alter table escrow_transactions
  add column if not exists provider text not null default 'tradesafe',
  add column if not exists provider_transaction_id text,
  add column if not exists provider_allocation_id text,
  add column if not exists provider_state text;

alter table escrow_transactions
  drop constraint if exists escrow_transactions_status_check;

alter table escrow_transactions
  add constraint escrow_transactions_status_check
  check (status in ('pending', 'held', 'released', 'refunded', 'failed', 'cancelled'));

create unique index if not exists idx_profiles_tradesafe_token_id
  on profiles(tradesafe_token_id)
  where tradesafe_token_id is not null;

create unique index if not exists idx_orders_payment_reference
  on orders(payment_reference)
  where payment_reference is not null;

create unique index if not exists idx_orders_tradesafe_transaction_id
  on orders(tradesafe_transaction_id)
  where tradesafe_transaction_id is not null;
