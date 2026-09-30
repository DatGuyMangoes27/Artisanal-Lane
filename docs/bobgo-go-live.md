# Bob Go go-live runbook

Bob Go is an additional door-to-door option. Courier Guy, Pargo, market pickup
and fixed-price delivery are unchanged. Everything below is **off in production
until both flags are flipped** (see "Production flag flip").

Status when this was written: the database foundation
(`20260817150500_add_bobgo_shipping_foundation.sql`) is applied in production.
The follow-up migration, all Edge Function changes, the website and the app
changes are **not deployed**.

## How it works

1. Buyer enters a delivery address. The website (`/api/marketplace/bobgo/rates`)
   or the app (`bobgo-quote` Edge Function) asks Bob Go for VAT-inclusive
   door-to-door rates and saves the quote server-side for 20 minutes, bound to
   buyer, shop, basket and address.
2. `create-checkout` ignores any client price. It verifies the saved quote
   (buyer, shop, basket, address, rate, expiry) and adds the rate to the total.
3. The rate is carried in TradeSafe as a fixed `AGENT` fee paid to the Artisan
   Lane token (`TRADESAFE_ARTISAN_LANE_TOKEN_ID`). The artisan stays the seller.
4. When TradeSafe confirms payment, `tradesafe-callback` books the courier
   (compare-and-set on `bobgo_booking_state`, so duplicate callbacks cannot
   double-book). Tracking number, tracking URL and status are saved on the order.
5. Updates: Bob Go webhook -> `bobgo-webhook`; backstop poll and
   unbooked-order sweep -> `bobgo-sync-tracking` (scheduled).
6. The artisan downloads the waybill (website route / `bobgo-shipment`), hands
   the parcel over and taps "Mark shipped" (`mark-order-shipped`, which for Bob
   Go orders requires a booked courier and uses the booked tracking details).
7. Refund: `process-refund` cancels the TradeSafe transaction (money first), then
   cancels the booked courier best-effort and records any failure.

## Secrets and environment (names only)

Supabase Edge Function secrets:

| Name | Purpose |
| --- | --- |
| `BOBGO_SANDBOX_API_KEY` | Bob Go API key (read by all Bob Go functions) |
| `BOBGO_SANDBOX_BASE_URL` | Optional. Defaults to the sandbox `/v2` base URL |
| `BOBGO_SHIPPING_ENABLED` | Server switch. Must be exactly `true` to enable |
| `BOBGO_WEBHOOK_SECRET` | Shared secret Bob Go sends to `bobgo-webhook` |
| `BOBGO_SYNC_SECRET` | Optional header secret for `bobgo-sync-tracking` |
| `BOBGO_CANCEL_PATH` | Optional cancel path override, `{id}` = shipment id |
| `TRADESAFE_ARTISAN_LANE_TOKEN_ID` | Artisan Lane TradeSafe token receiving the AGENT fee |
| `TRADESAFE_CLIENT_ID`, `TRADESAFE_CLIENT_SECRET`, `TRADESAFE_CALLBACK_SECRET` | Already set for TradeSafe |

Website (`landing/`) environment:

| Name | Purpose |
| --- | --- |
| `BOBGO_SHIPPING_ENABLED` | Server flag for the rates and waybill routes |
| `NEXT_PUBLIC_BOBGO_SHIPPING_ENABLED` | Shows Bob Go in checkout |
| `BOBGO_SANDBOX_API_KEY`, `BOBGO_SANDBOX_BASE_URL` | Same Bob Go credentials |

The variable names say `SANDBOX` because that is what the code reads. For live
use, put the live key and live base URL in those same variables.

The mobile app needs **no** Bob Go secret or flag: it asks the server whether
Bob Go is available, so it stays hidden while `BOBGO_SHIPPING_ENABLED` is off.

## Deploy order

Sandbox/dev first, production only after the sandbox script below passes.

1. Apply `20260929120000_bobgo_tracking_and_cancellation.sql` (additive: new
   order columns, `cancelled` booking state, indexes). **Must precede the
   functions**: booking now reads `bobgo_booking_attempts`.
2. Set the secrets above with `BOBGO_SHIPPING_ENABLED` unset or `false`.
3. Deploy functions: `create-checkout`, `tradesafe-callback`, `mark-order-shipped`,
   `process-refund`, then the new `bobgo-quote`, `bobgo-shipment`,
   `bobgo-webhook`, `bobgo-sync-tracking`. `bobgo-webhook` and
   `bobgo-sync-tracking` must be deployed with JWT verification off (already in
   `supabase/config.toml`).
4. Register the Bob Go webhook (topics `tracking/updated`, and
   `shipment_submission_status/updated` if available) pointing at
   `https://<project>.functions.supabase.co/bobgo-webhook?secret=<BOBGO_WEBHOOK_SECRET>`.
5. Schedule `bobgo-sync-tracking` every 15 minutes (POST with header
   `x-bobgo-sync-secret`, or the service-role bearer token if the secret is unset).
6. Deploy the website, then release the app build.
7. Confirm with the flag still off: non-Bob Go checkout works exactly as before,
   Bob Go is not offered on web or in the app, `bobgo-quote` returns
   `available: false`.

## Sandbox test script

Prerequisites: sandbox Supabase + TradeSafe sandbox, Bob Go sandbox key, an
artisan shop with payout details, one product with packed weight and size, a
buyer account. Flag on in the sandbox only.

| # | Step | Expected |
| --- | --- | --- |
| 1 | Artisan: Shop settings -> "Courier delivery (Bob Go)" (web or app): add contact, collection address, enable, save | Saved; app shows the section only when the server flag is on |
| 2 | Artisan: product form -> packed weight, length, width, height | Saved; leaving all four blank is allowed; partial values are rejected |
| 3 | Buyer: add the product, checkout, choose "Bob Go Door to Door", fill address incl. suburb, "Get delivery rates" | VAT-inclusive rates (R x.xx incl. VAT), ETA if the courier supplies one, cheapest first. Row in `bobgo_shipping_quotes` |
| 4 | Change the street after quoting | Quote marked out of date; Pay blocked until rates are refreshed |
| 5 | Wait 20 minutes (or set `expires_at` in the past) then try to pay | "quote expired" message; a fresh quote fixes it |
| 6 | Pay with a TradeSafe sandbox test payment | Order `paid`; TradeSafe transaction total = items + Bob Go rate; AGENT party = Artisan Lane token with the fixed shipping fee; seller payout excludes shipping |
| 7 | Check the order | `bobgo_booking_state = booked`, `bobgo_shipment_id`, `tracking_number`, `bobgo_charged_amount` set. Compare `bobgo_charged_amount` with the quoted amount and note any difference |
| 8 | Replay the same TradeSafe callback | No second shipment (state already `booked`) |
| 9 | Artisan order screen (web and app) | Courier card shows "Booked - waiting for courier collection"; waybill downloads as a PDF; Mark shipped works without typing tracking |
| 10 | Buyer order screen | Courier status and tracking number visible |
| 11 | Fire a tracking update (Bob Go sandbox event or POST a sample payload to `bobgo-webhook`) | `bobgo_status` and `bobgo_last_event_at` update; buyer and artisan see the new status; a wrong `secret` returns 401; an older event is ignored |
| 12 | Call `bobgo-sync-tracking` manually | Open shipments polled; `bobgo_delivered_at` set on delivery; no effect while the flag is off |
| 13 | Force a booking failure (invalid service level in the sandbox) | Order stays `paid`, `bobgo_booking_state = failed` with `bobgo_booking_error`; artisan sees "Book courier again"; fixing the cause then retry (or the sweep) books it |
| 14 | Cancel and refund an order with a booked courier (admin `process-refund`) | TradeSafe transaction cancelled, order `cancelled`/`refunded`, `bobgo_booking_state = cancelled`, `bobgo_cancelled_at` set. If Bob Go refuses, the response contains `bobGoCancelError`, the refund still stands and `bobgo_cancel_error` records why |
| 15 | Refund after delivery | Courier cancel skipped (already delivered); refund completes |
| 16 | Confirm the buyer's TradeSafe refund includes the shipping amount and that the AGENT fee is reversed | Verify in the TradeSafe sandbox; escalate before go-live if not |

## Things that must be confirmed in the sandbox

The public Bob Go docs available while building did not specify these, so the
code is tolerant and flags them here rather than guessing silently:

- Cancellation endpoint (implemented as `POST /shipments/{id}/cancel`, override
  with `BOBGO_CANCEL_PATH`).
- Tracking webhook payload shape and status vocabulary (unknown statuses show as
  "In progress" and are stored verbatim). The parsing lives in
  `supabase/functions/_shared/bobgo-tracking.mjs`.
- Whether the shipment response returns a tracking URL, and the exact rate ETA
  field names (parsed defensively; ETA is simply hidden when absent).
- `GET /tracking` and `GET /shipments/waybill` accept `tracking_reference`.
- Whether `bobgo_charged_amount` can differ from the quoted VAT-inclusive rate.
  There is no automatic reconciliation of a difference; decide the policy.

An order stuck in `booking` (function died mid-call) is **not** auto-retried
because Bob Go may already have accepted it. Check Bob Go for a shipment with
the order id as custom reference, then either set the shipment id manually or
reset the state to `failed`.

## Production flag flip

Do this only after the sandbox script passes and sign-off.

1. Live Bob Go credentials in `BOBGO_SANDBOX_API_KEY` / `BOBGO_SANDBOX_BASE_URL`
   (Edge Function secrets and website env), live webhook registered.
2. Set Edge Function secret `BOBGO_SHIPPING_ENABLED=true`.
3. Set website env `BOBGO_SHIPPING_ENABLED=true` and
   `NEXT_PUBLIC_BOBGO_SHIPPING_ENABLED=true`, redeploy the website.
4. The app follows automatically. Artisans opt in per shop via Shop settings.
5. Watch for `[bobgo]` log lines, `bobgo_booking_state = failed` orders and
   `bobgo_cancel_error` values for the first day.

Rollback: set the Edge Function `BOBGO_SHIPPING_ENABLED` to anything but `true`
and the website flags to `false`. New Bob Go checkouts stop immediately; orders
already booked keep their courier and existing tracking data.
