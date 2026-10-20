# Multi-shop checkout

Buyers can check out a basket with items from several shops in one go and pay
once. Each artisan is still paid on their own delivery, and refunds stay per
shop, exactly like single-shop orders.

## How it works

1. `create-checkout` gets `shops[]` (one delivery choice per shop). With one
   shop it runs the original single-shop flow unchanged.
2. For several shops it creates a **checkout group** (`checkout_groups`,
   status `building`), then for each shop: the order (linked to the group), its
   items and stock, and a normal TradeSafe transaction (buyer + that artisan as
   seller, Bob Go as an AGENT fee as usual).
3. It adds up what the buyer owes across those transactions and creates **one
   TradeSafe payment link** (`tokenDeposit`) that tops up the buyer's own
   TradeSafe wallet for that total (whole rands). The group becomes
   `awaiting_payment`.
4. Once the money is in the wallet, `fundCheckoutGroup`
   (`supabase/functions/_shared/checkout-groups.ts`) pays each shop's
   transaction from it (`transactionDepositWallet`) and marks each order paid
   (courier booking, chat, push - the same as the TradeSafe callback). The group
   becomes `funded` and the cart is cleared. This runs:
   - while the buyer is paying: the app and website poll `checkout-group-status`;
   - every 5 minutes: `cleanup-stale-checkouts`;
   - when the buyer starts a new basket (an older unpaid one is settled first).
5. From here every order is an ordinary order: the artisan ships, the buyer
   accepts, TradeSafe pays that artisan. Refunds (`process-refund`) cancel only
   that shop's transaction; the money goes back to the buyer's TradeSafe wallet.

Why not one TradeSafe transaction with each shop as a payee? Tested in the
sandbox (Oct 2026): payees' amounts are fixed once paid, so refunding one shop
would come out of Artisan Lane's pocket, and payees are only paid once every
parcel is accepted.

## Safety rules

- A basket is only ever funded, expired or cancelled by `fundCheckoutGroup`
  while it holds the group's claim. Stale cleanup skips basket orders
  (`cancel_stale_checkout_orders` excludes `checkout_group_id`).
- `orders.group_funded_at` is set the moment a transaction is paid from the
  wallet; such an order is never paid again or cancelled by expiry.
- An unpaid basket expires as a whole 15 minutes after its 30-minute payment
  link (all its orders cancelled, stock returned, transactions cancelled).
- A basket that fails while being created is undone completely.

## Small change in the wallet

TradeSafe charges slightly less when a transaction is paid from the wallet than
the card/EFT quote the payment was based on, and the link is in whole rands, so
about R1-R2 usually stays in the buyer's TradeSafe wallet. It counts towards
their next multi-shop checkout. A payment that arrives after a basket expired
also stays in their wallet and is used next time.

## Admin: what to watch

```sql
-- Baskets that need a person (part paid, or stuck):
select id, buyer_id, status, total_due, last_error, created_at
from checkout_groups
where status = 'needs_attention'
   or (status in ('building', 'awaiting_payment') and created_at < now() - interval '2 hours');
```

`needs_attention` means only part of a basket could be paid. Check the
buyer's TradeSafe wallet and either fund the remaining shop transaction in the
TradeSafe dashboard or refund the buyer.

## Testing

- `node scripts/test-multi-shop-checkout-groups-policies.mjs` (database rules).
- `deno test -A --env-file=<sandbox.env> supabase/functions/_shared/checkout-groups_sandbox_test.ts`
  runs against the TradeSafe **sandbox** (env file with sandbox
  `TRADESAFE_CLIENT_ID`, `TRADESAFE_CLIENT_SECRET` and
  `TRADESAFE_GRAPHQL_URL=https://api-developer.tradesafe.dev/graphql`; never
  commit it).
