# Bob Go sandbox shipping

Bob Go is an additional door-to-door option. Courier Guy, Pargo, market pickup,
and the existing fixed-price delivery choices remain unchanged.

## Local configuration

1. Apply `supabase/migrations/20260817150500_add_bobgo_shipping_foundation.sql`
   (already live in production as version 20260817132555) and then
   `20260929120000_bobgo_tracking_and_cancellation.sql` to a local Supabase
   database or a disposable Supabase development branch.
2. Set the Bob Go sandbox variables shown in `landing/.env.example`.
3. Set the Edge Function variables shown in `supabase/functions/.env.example`.
4. Add a private collection address in **Vendor > Shop settings** and enable
   Bob Go for that shop.
5. Add packed weight and dimensions to each product included in the test cart.

In local development the web checkout can offer Bob Go when a sandbox key is
configured, but only for carts whose artisan enabled Bob Go with complete
collection details and whose products have parcel measurements (the same rule
as the app). Production remains disabled unless the flags are explicitly
enabled.

## Payment and booking flow

- Bob Go returns VAT-inclusive door-to-door rates.
- Checkout saves the quote server-side for 20 minutes and binds it to the buyer,
  shop, basket, and delivery address.
- `create-checkout` ignores the browser's price and uses the saved rate.
- The Bob Go amount is represented in TradeSafe as a fixed `AGENT` payout to
  the Artisan Lane token. The artisan remains the seller.
- A courier shipment is booked only after TradeSafe confirms payment. The
  booking state prevents duplicate callbacks from creating duplicate shipments.

Do not deploy the migration or Edge Function changes until the sandbox checkout,
payment callback, shipment, waybill, cancellation, and refund cases are signed off.

See `docs/bobgo-go-live.md` for secrets, deploy order, the sandbox test script and the production flag flip.
