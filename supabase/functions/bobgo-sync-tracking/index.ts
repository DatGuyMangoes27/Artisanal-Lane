// Scheduled reconciliation for Bob Go orders (run every ~15 minutes via
// pg_cron / Supabase scheduled invocation, see docs/bobgo-go-live.md):
//   1. polls GET /tracking for booked, undelivered shipments (backstop for
//      missed webhooks);
//   2. books paid Bob Go orders that never got a shipment (payment reconciled by
//      cleanup-stale-checkouts, or a previous booking attempt failed).
// Auth: service-role bearer, or the x-bobgo-sync-secret header when
// BOBGO_SYNC_SECRET is set. Disabled unless BOBGO_SHIPPING_ENABLED=true.

import { createClient } from "npm:@supabase/supabase-js@2";

import { getBobGoTracking, isBobGoEnabled } from "../_shared/bobgo.ts";
import { bookBobGoShipmentForOrder } from "../_shared/bobgo-booking.ts";
import { applyBobGoTrackingSnapshot, BOBGO_ORDER_TRACKING_COLUMNS } from "../_shared/bobgo-sync.ts";
import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { isValidWebhookSecret } from "../_shared/bobgo-tracking.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const syncSecret = Deno.env.get("BOBGO_SYNC_SECRET");
const TRACK_BATCH = 40;
const BOOK_BATCH = 10;
// Do not touch payments younger than this: the callback is normally booking it.
const BOOKING_GRACE_MINUTES = 5;

function isAuthorized(request: Request) {
  if (syncSecret) {
    return isValidWebhookSecret(request.headers.get("x-bobgo-sync-secret") ?? "", syncSecret);
  }
  try {
    return getBearerToken(request) === supabaseServiceRoleKey;
  } catch (_) {
    return false;
  }
}

Deno.serve(async (request) => {
  try {
    if (!isAuthorized(request)) return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    if (!isBobGoEnabled()) return jsonResponse({ ok: true, skipped: "bobgo_disabled" });

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const tracked: string[] = [];
    const trackFailures: Array<{ orderId: string; error: string }> = [];
    const { data: open } = await admin
      .from("orders")
      .select(BOBGO_ORDER_TRACKING_COLUMNS)
      .eq("shipping_method", "bobgo_door_to_door")
      .eq("bobgo_booking_state", "booked")
      .is("bobgo_delivered_at", null)
      .is("bobgo_cancelled_at", null)
      .not("tracking_number", "is", null)
      .order("bobgo_last_event_at", { ascending: true, nullsFirst: true })
      .limit(TRACK_BATCH);

    for (const order of open ?? []) {
      try {
        const snapshot = await getBobGoTracking(order.tracking_number as string);
        if (snapshot && await applyBobGoTrackingSnapshot(admin, order, snapshot)) {
          tracked.push(order.id as string);
        }
      } catch (error) {
        trackFailures.push({
          orderId: order.id as string,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    const cutoff = new Date(Date.now() - BOOKING_GRACE_MINUTES * 60 * 1000).toISOString();
    const { data: unbooked } = await admin
      .from("orders")
      .select(
        "id, shipping_method, bobgo_quote_id, bobgo_provider_slug, bobgo_service_level_code, bobgo_shipment_id",
      )
      .eq("shipping_method", "bobgo_door_to_door")
      .in("status", ["paid", "completed"])
      .in("bobgo_booking_state", ["not_requested", "failed"])
      .is("bobgo_shipment_id", null)
      .lte("paid_at", cutoff)
      .lt("bobgo_booking_attempts", 5)
      .order("paid_at", { ascending: true })
      .limit(BOOK_BATCH);

    const booked: string[] = [];
    const bookFailures: Array<{ orderId: string; error: string }> = [];
    for (const order of unbooked ?? []) {
      const result = await bookBobGoShipmentForOrder(admin, order);
      if (result.outcome === "booked") booked.push(order.id as string);
      if (result.outcome === "failed") {
        bookFailures.push({ orderId: order.id as string, error: result.error });
      }
    }

    return jsonResponse({ ok: true, tracked, trackFailures, booked, bookFailures });
  } catch (error) {
    console.error("[bobgo-sync-tracking] failed", error);
    return jsonResponse({ error: "Sync failed." }, { status: 500 });
  }
});
