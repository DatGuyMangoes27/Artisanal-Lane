# Bob Go go-live runbook

Bob Go is an additional door-to-door option. Courier Guy (locker and door to
door), Pargo, market pickup and the fixed-price options are unchanged. Nothing
below changes production behaviour until the **production flag flip** at the
end. The mobile app (1.3.0 and later) needs **no release**: it only shows Bob Go
when the server says so.

Live state when this was written (18 Oct 2026, project `byckurabenbunsbrzcpl`):

- Applied: the foundation migration, recorded in production as
  `20260817132555 add_bobgo_shipping_foundation` (the repo file is
  `20260817150500_add_bobgo_shipping_foundation.sql`; same content, different
  version number).
- Not applied / not deployed: `20260929120000_bobgo_tracking_and_cancellation.sql`,
  the functions `bobgo-quote`, `bobgo-shipment`, `bobgo-webhook`,
  `bobgo-sync-tracking`, and the Bob Go versions of `create-checkout` (live v65),
  `tradesafe-callback`, `process-refund`, `mark-order-shipped`.
- 10 shops already have a `shop_fulfillment_profiles` row, 8 with
  `bobgo_enabled = true`; 99 products have parcel measurements; 0 Bob Go orders.
  Those 8 shops are offered Bob Go as soon as the flag is on (if their
  collection details are complete and the cart's products have parcel sizes).

API reference used: Bob Go's official Postman collection
(<https://api-docs.bob.co.za/postman-collections/bobgo.postman_collection.json>,
linked from <https://api-docs.bob.co.za/bobgo>). The webhook signature was taken
from Bob Group's official WooCommerce plugin (`bobgo-shipping`,
<https://downloads.wordpress.org/plugin/bobgo-shipping.zip>, `app/class-webhook.php`).

## How it works

1. **Quote.** Buyer enters an address. Website `/api/marketplace/bobgo/rates/`
   or app `bobgo-quote` calls `POST /rates`, keeps VAT-inclusive door rates
   (`rate_amount`, cheapest first, zero/invalid rates dropped) and saves the quote
   for 20 minutes in `bobgo_shipping_quotes`, bound to buyer, shop, cart lines,
   address and contact. Quotes are only readable by the service role.
2. **Offer gating.** Bob Go is offered only when: the server flag is on, the
   artisan has `bobgo_enabled` **and** complete collection details (name, valid
   email, phone, street, suburb, city, province, postal code), every product in
   the cart has all four parcel measurements, the cart is one shop and at most 20
   parcels. App: `bobgo-quote` action `availability`. Website:
   `/api/marketplace/bobgo/availability/`. Same rules in both.
3. **Checkout.** `create-checkout` ignores any client price. It re-checks the
   artisan profile, the quote (buyer, shop, cart lines, address, not expired) and
   the chosen rate (provider + service level + rate response id, amount > 0), and
   charges that rate. TradeSafe total = items - discount + Bob Go rate (+ gift
   fee). The rate is a fixed `AGENT` fee to `TRADESAFE_ARTISAN_LANE_TOKEN_ID`, so
   the artisan's payout excludes shipping.
4. **Booking.** On the TradeSafe "paid" callback, `tradesafe-callback` books the
   courier (`POST /shipments`, custom reference = order id). Double booking is
   prevented by a compare-and-set claim (`status = 'paid'`, booking state
   `not_requested|failed`), by looking Bob Go up (`GET /shipments?tracking_reference=<order id>`)
   before every retry, and by never re-booking an order stuck in `booking`.
   A booking that finishes after a refund is cancelled straight away.
5. **Tracking.** Bob Go webhooks -> `bobgo-webhook` (signed). Every 15 minutes
   `bobgo-sync-tracking` polls `GET /tracking`, retries failed/unbooked paid orders
   (max 5 attempts), adopts shipments for orders stuck in `booking`, and logs
   orders needing attention. Out-of-order and replayed events are ignored.
   Statuses unknown to released clients are stored as aliases they understand
   (e.g. `delivery-exception` -> `exception`); the raw status stays in
   `bobgo_tracking_events`.
6. **Hand-over.** The artisan downloads the waybill (website
   `/api/vendor/bobgo-waybill/`, app via `bobgo-shipment`), hands the parcel over
   and taps "Mark shipped" (needs a booked courier; tracking comes from Bob Go).
7. **Refund.** `process-refund` cancels the TradeSafe transaction (money first),
   marks the order cancelled (no booking can start after this), then cancels the
   courier with `POST /shipments/cancel {tracking_reference}`. A Bob Go refusal
   (e.g. already collected) is recorded in `bobgo_cancel_error` and returned as
   `bobGoCancelError`; the refund stands.

Admin visibility: website **Admin -> Orders** shows a "Bob Go needs attention"
panel (failed/stuck bookings, courier refusals, failed cancellations, courier
charges above what the buyer paid) and a Bob Go filter.

## Secrets and environment (names only)

Supabase Edge Function secrets:

| Name | Purpose |
| --- | --- |
| `BOBGO_SANDBOX_API_KEY` | Bob Go API key. Name says SANDBOX for history; holds the live key in production |
| `BOBGO_SANDBOX_BASE_URL` | `https://api.sandbox.bobgo.co.za/v2` (sandbox) or `https://api.bobgo.co.za/v2` (live). Defaults to sandbox when unset |
| `BOBGO_SHIPPING_ENABLED` | Switch for **new** Bob Go checkouts. Only the exact value `true` enables it |
| `BOBGO_WEBHOOK_SECRET` | Webhook signing secret generated in the Bob Go dashboard (Settings -> Webhook subscriptions) |
| `BOBGO_WEBHOOK_REQUIRE_SIGNATURE` | Set `true` once signed webhooks are confirmed (turns off the `?secret=` fallback) |
| `BOBGO_SYNC_SECRET` | Header secret for the scheduled `bobgo-sync-tracking` call |
| `TRADESAFE_ARTISAN_LANE_TOKEN_ID` | Artisan Lane TradeSafe token that receives the AGENT shipping fee. Bob Go is never offered without it |
| `TRADESAFE_CLIENT_ID`, `TRADESAFE_CLIENT_SECRET`, `TRADESAFE_CALLBACK_SECRET` | Already set |

`BOBGO_CANCEL_PATH` is no longer used (the documented cancel endpoint is built in).

Vault secret (for the cron job): `bobgo_sync_secret` (same value as `BOBGO_SYNC_SECRET`).

Website (`landing/`) environment:

| Name | Purpose |
| --- | --- |
| `BOBGO_SHIPPING_ENABLED` | Server flag: rates + availability routes, vendor Bob Go settings and parcel fields |
| `NEXT_PUBLIC_BOBGO_SHIPPING_ENABLED` | Lets checkout ask the availability route (build-time; redeploy after changing) |
| `BOBGO_SANDBOX_API_KEY`, `BOBGO_SANDBOX_BASE_URL` | Same Bob Go credentials (waybill route needs only these) |

What each switch controls:

- Flags **off**, key **set**: no Bob Go offered anywhere, no new Bob Go orders;
  Bob Go orders that already exist keep being booked, tracked, cancelled and
  their waybills keep downloading. With zero Bob Go orders this is a no-op.
- Key **unset**: every Bob Go function is inert (sync returns
  `bobgo_not_configured`, `bobgo-shipment` and the waybill route return 404).

## Deploy order

Do the whole sequence on a Supabase **development branch / sandbox project
first** (with the Bob Go sandbox key), run the sandbox script, then repeat steps
1-8 on production with the flag still off, and flip the flag last.

1. **Migration.** Apply `supabase/migrations/20260929120000_bobgo_tracking_and_cancellation.sql`
   on its own (MCP `apply_migration` with name `bobgo_tracking_and_cancellation`,
   or the SQL editor). Do **not** use `supabase db push`: production's migration
   history uses different version numbers for several files. The migration is
   additive and re-runnable. It must precede the functions (they write
   `bobgo_booking_attempts`, `bobgo_booking_started_at`, ...).
   Verify: `select bobgo_booking_attempts, bobgo_booking_started_at from orders limit 1;`
2. **Secrets.** Set the Edge Function secrets above with
   `BOBGO_SHIPPING_ENABLED=false` (or unset) and
   `BOBGO_WEBHOOK_REQUIRE_SIGNATURE=false`.
3. **Shared code.** There is no separate deploy for `_shared/`: each function
   deploy bundles the `_shared` files it imports (`bobgo.ts`, `bobgo-rates.ts`,
   `bobgo-booking.ts`, `bobgo-sync.ts`, `bobgo-tracking.mjs`, `tradesafe.ts`,
   `http.ts`, `push.ts`, ...). Deploy every function in step 4 from the same
   checkout so they all carry the same shared code.
4. **Functions** (CLI: `supabase functions deploy <name> --project-ref <ref>`;
   `config.toml` already holds the `verify_jwt = false` entries):

   | Order | Function | verify_jwt | Notes |
   | --- | --- | --- | --- |
   | 1 | `bobgo-quote` | true (default) | New. Returns `available:false` while the flag is off |
   | 2 | `bobgo-shipment` | true (default) | New. Vendor/admin waybill + retry |
   | 3 | `bobgo-webhook` | **false** | New. Signature/secret checked inside |
   | 4 | `bobgo-sync-tracking` | **false** | New. Secret checked inside |
   | 5 | `process-refund` | true (live: true) | Courier cancellation after refund. Bundles the newer `_shared/push.ts`; a push failure is caught so the refund response stays `ok` as today |
   | 6 | `mark-order-shipped` | true (live: true) | Bob Go orders need a booked courier |
   | 7 | `tradesafe-callback` | **false** (live: false) | Books the courier after payment |
   | 8 | `create-checkout` | true (live: true) | Last. Keeps the 5-day payment grace from live v65 |

   The repo `create-checkout` equals live v65 plus the Bob Go branch (inert
   while the flag is off), a `shop` null guard and type fixes. Non-Bob Go
   TradeSafe transactions are created with exactly the same mutation as today.
5. **Website.** Set the website env with both flags `false`, deploy `landing/`.
6. **Webhook registration** (Bob Go dashboard, or API with the same key):
   `POST {BASE_URL}/webhooks` with body
   `{"webhook_subscriptions":[{"delivery_url":"https://<ref>.supabase.co/functions/v1/bobgo-webhook","topic":"tracking/updated","status":"active"}, ... ]}`
   for the topics `tracking/updated`, `shipment_submission_status/updated` and
   `shipment_charged_amount/updated`. Generate the webhook signing secret in the
   dashboard (Settings -> Webhook subscriptions) and store it as
   `BOBGO_WEBHOOK_SECRET`. If the sandbox does not send `Bobgo-Webhook-Signature`,
   use `.../bobgo-webhook?secret=<BOBGO_WEBHOOK_SECRET>` as the delivery URL
   until it does. Check with `GET {BASE_URL}/webhooks`.
7. **Scheduled sync** (pg_cron + pg_net are enabled in production). Store the
   sync secret in Vault as `bobgo_sync_secret`, then:

   ```sql
   select cron.schedule(
     'bobgo-sync-tracking-every-15-minutes',
     '*/15 * * * *',
     $$
     select net.http_post(
       url := 'https://<ref>.supabase.co/functions/v1/bobgo-sync-tracking',
       headers := jsonb_build_object(
         'Content-Type', 'application/json',
         'x-bobgo-sync-secret',
         (select decrypted_secret from vault.decrypted_secrets where name = 'bobgo_sync_secret')
       ),
       body := '{}'::jsonb
     );
     $$
   );
   ```

   Safe with the flag off: it only touches existing Bob Go orders.
8. **Flag-off verification** (production, flag still off): a normal checkout
   (Courier Guy, Pargo, market pickup) works exactly as before; Bob Go is not
   shown on web checkout, vendor shop settings, the web product form or in the
   app; `bobgo-quote` with `{"action":"availability"}` returns
   `{"available":false,"reason":"disabled"}`; `bobgo-sync-tracking` returns
   `ok` with empty lists; a refund of a non-Bob Go order behaves as before.
9. **Sandbox script** (below) on the sandbox/dev environment with the flag on.
10. **Production flip** (below).

## Sandbox test script

Prerequisites: sandbox Supabase (or branch) + TradeSafe sandbox, Bob Go sandbox
key, `TRADESAFE_ARTISAN_LANE_TOKEN_ID` for the sandbox, an artisan shop with
payout details and an active subscription, one product with packed weight and
size, a buyer account. Flags on in the sandbox only.

| # | Step | Expected |
| --- | --- | --- |
| 1 | Artisan: Shop settings -> "Courier delivery (Bob Go)" (app) / "Bob Go collection address" (web): contact, collection address, enable, save | Saved; the section only appears with the flag on |
| 2 | Artisan: product form -> packed weight, length, width, height | Saved; all four blank allowed; partial values rejected (web and app) |
| 3 | Buyer: cart from a shop **without** Bob Go enabled | Bob Go not offered (web and app) |
| 4 | Buyer: cart from the Bob Go shop, choose "Bob Go Door to Door", address incl. suburb, "Get delivery rates" | VAT-inclusive rates, cheapest first, ETA only if supplied. Row in `bobgo_shipping_quotes`. **Record the raw `POST /rates` response** |
| 5 | Change the street after quoting | Quote marked out of date; pay blocked until refreshed |
| 6 | Wait 20 min (or set `expires_at` in the past), pay | "quote expired"; a fresh quote fixes it |
| 7 | Tamper: call `create-checkout` with another rate's id/price or another buyer's quote id | Rejected; only the saved rate is ever charged |
| 8 | Pay with a TradeSafe sandbox payment | Order `paid`; TradeSafe total = items + rate; AGENT party = Artisan Lane token with the rate as fixed fee; seller payout excludes shipping |
| 9 | Check the order | `bobgo_booking_state = booked`, `bobgo_shipment_id`, `tracking_number` (Bob Go tracking reference), `bobgo_charged_amount`. **Record the raw `POST /shipments` response**; compare `bobgo_charged_amount` with the quote |
| 10 | Replay the same TradeSafe callback | No second shipment |
| 11 | Artisan order screen (web and app) | "Booked - waiting for courier collection"; waybill opens as a PDF (**record the waybill response content type**); Mark shipped works without typing tracking |
| 12 | Buyer order screen | Courier status and tracking number visible |
| 13 | Tracking webhook (sandbox event, or POST a signed sample to `bobgo-webhook`) | `bobgo_status`, `bobgo_last_event_at`, `bobgo_tracking_events` update; unsigned / wrong secret -> 401; older event ignored; replay -> `changed:false`. **Record the headers and body Bob Go sends** |
| 14 | Call `bobgo-sync-tracking` (header `x-bobgo-sync-secret`) | Open shipments polled (**record the raw `GET /tracking` response**); `bobgo_delivered_at` set on delivery |
| 15 | Force a booking failure (invalid service level) | Order stays `paid`, `bobgo_booking_state = failed`, `bobgo_booking_error` set, admin panel lists it; "Book courier again" (web/app) or the sweep books it **once**; `GET /shipments?tracking_reference=<order id>` lookup finds the shipment (**confirm it matches the custom reference**) |
| 16 | Simulate a stuck booking: set `bobgo_booking_state='booking'`, `bobgo_booking_started_at` 20 min ago on an order Bob Go already has a shipment for | Sync adopts it (`adopted`), no second shipment |
| 17 | Refund an order with a booked, uncollected courier (admin `process-refund`) | TradeSafe cancelled, order `cancelled`/`refunded`, `bobgo_booking_state = cancelled`, `bobgo_cancelled_at` set. **Record the `POST /shipments/cancel` response** |
| 18 | Refund after collection/delivery | Refund completes; Bob Go refusal in `bobgo_cancel_error` + admin panel (collection), or cancel skipped (delivered) |
| 19 | Confirm the buyer's TradeSafe refund includes shipping and the AGENT fee is reversed | Verify in the TradeSafe sandbox; escalate before go-live if not |
| 20 | Flip the sandbox flag off with a Bob Go order paid but unbooked | Bob Go disappears from checkout; the order still gets booked by the sweep; waybill still downloads |

## Still to confirm in the sandbox

The code follows the official API reference and is tolerant where the
reference shows no example. Confirm and, if different, adjust the named file:

1. `POST /rates` response shape (`provider_rate_requests[].responses[]`,
   `rate_amount` incl. VAT, `rate_amount_excl_vat`, `service_level.delivery_type
   = "door"`) and whether any ETA fields exist (none documented; ETA is hidden
   when absent). `_shared/bobgo-rates.ts`, `landing/src/lib/bobgo.ts`.
2. `POST /shipments` response: `id`, `tracking_reference`, `status`,
   `submission_status`, `charged_amount`, and whether a tracking URL is returned
   (none documented). `_shared/bobgo.ts` (`parseBobGoShipment`).
3. `GET /shipments?tracking_reference=<order id>` matches our
   `custom_tracking_reference` (reported by a third party, not in the docs).
   If it does not, double-booking protection relies on the claim only; set stuck
   bookings manually after checking the Bob Go dashboard.
4. Maximum length/format of `custom_tracking_reference` / `custom_order_number`
   (we send the 36-character order UUID).
5. Waybill: `GET /shipments/waybill?tracking_references=["REF"]` returns a PDF or
   JSON with a link/base64 (both handled).
6. `GET /tracking` returns an array; status vocabulary (documented:
   `pending-collection, collected, in-transit, out-for-delivery, delivered,
   cancelled, collection-exception, delivery-exception, failed-collection,
   failed-delivery, finalised, ready-for-pickup`; `finalised` and return statuses
   are shown as "In progress").
7. `POST /shipments/cancel {tracking_reference}` success/refusal responses.
8. Webhook: header name `Bobgo-Webhook-Signature` and base64 HMAC-SHA256 of the
   raw body (from the official WooCommerce plugin, not the API docs). Once
   confirmed set `BOBGO_WEBHOOK_REQUIRE_SIGNATURE=true` and drop `?secret=` from
   the delivery URL.
9. Money policy: whether `charged_amount` can exceed the quoted VAT-inclusive
   rate. Differences are not charged to the buyer; Artisan Lane absorbs them and
   the admin panel flags them. TradeSafe's processing fee share is calculated on
   the full amount including shipping.

## Production flag flip

Only after the sandbox script passes and sign-off.

1. Edge Function secrets: live key in `BOBGO_SANDBOX_API_KEY`,
   `BOBGO_SANDBOX_BASE_URL=https://api.bobgo.co.za/v2`, live
   `BOBGO_WEBHOOK_SECRET`; live webhooks registered (step 6 against the live
   base URL); live `TRADESAFE_ARTISAN_LANE_TOKEN_ID`.
2. Set Edge Function secret `BOBGO_SHIPPING_ENABLED=true`.
3. Website env: `BOBGO_SHIPPING_ENABLED=true`, `NEXT_PUBLIC_BOBGO_SHIPPING_ENABLED=true`
   (plus the live key/base URL), redeploy the website.
4. The app follows automatically (vendor Bob Go section, product parcel fields
   and checkout option appear on next load). No app release is needed.
5. First day: watch `[bobgo]` log lines, the admin "Bob Go needs attention"
   panel, `bobgo_booking_state in ('failed','booking')` and `bobgo_cancel_error`.

## Rollback

Set the Edge Function secret `BOBGO_SHIPPING_ENABLED` to `false` and the website
flags to `false` (redeploy the website). New Bob Go quotes and checkouts stop
immediately on web and app. Keep `BOBGO_SANDBOX_API_KEY` set so paid Bob Go
orders are still booked, tracked, cancelled on refund, and their waybills still
download; remove the key only once no open Bob Go orders remain. A buyer who
already holds a quote cannot pay with it once the flag is off.

## Manual reconciliation

- **Stuck in `booking`** (listed in the admin panel and the sync response
  `needsAttention`): look for a shipment in the Bob Go dashboard whose custom
  reference is the order id. If found, set `bobgo_shipment_id`, `tracking_number`,
  `bobgo_booking_state='booked'`; if not, set `bobgo_booking_state='failed'` and
  the sweep or "Book courier again" retries.
- **Failed 5 times**: fix the cause (address, parcel size, courier), then reset
  `bobgo_booking_attempts` to 0 or use "Book courier again".
- **Courier refused after booking** (`shipment_submission_status/updated` with
  `failed-indefinitely`/`no-rates`): the order is released to `failed` for a
  fresh booking if not yet shipped.
