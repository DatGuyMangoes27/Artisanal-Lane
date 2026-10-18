// Scheduled reconciliation for Bob Go orders (every ~15 minutes, see
// docs/bobgo-go-live.md):
//   1. polls GET /tracking for booked, undelivered shipments (backstop for
//      missed webhooks);
//   2. books paid Bob Go orders that never got a shipment (payment reconciled by
//      cleanup-stale-checkouts, or an earlier attempt failed), max 5 attempts;
//   3. adopts shipments for orders stuck in 'booking' (function died after Bob Go
//      accepted) when Bob Go has one for the order; reports the rest.
// Auth: x-bobgo-sync-secret header (BOBGO_SYNC_SECRET), or the service-role
// bearer token when that secret is unset. verify_jwt is off (config.toml).
//
// Runs whenever Bob Go credentials are configured - NOT only while
// BOBGO_SHIPPING_ENABLED is on - so a rollback of new checkouts never strands
// orders that were already paid with Bob Go. With no Bob Go orders it is a no-op.
// Idempotent: every write is a compare-and-set or a monotonic tracking update.

import { createClient } from "npm:@supabase/supabase-js@2";

import { getBobGoTracking, isBobGoConfigured } from "../_shared/bobgo.ts";
import { bookBobGoShipmentForOrder, reconcileStuckBobGoBooking } from "../_shared/bobgo-booking.ts";
import { applyBobGoTrackingSnapshot, BOBGO_ORDER_TRACKING_COLUMNS } from "../_shared/bobgo-sync.ts";
import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { isValidWebhookSecret } from "../_shared/bobgo-tracking.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const syncSecret = Deno.env.get("BOBGO_SYNC_SECRET");
const TRACK_BATCH = 40;
const BOOK_BATCH = 10;
const MAX_BOOKING_ATTEMPTS = 5;
// Do not touch payments younger than this: the callback is normally booking it.
const BOOKING_GRACE_MINUTES = 5;
// A booking call times out after ~25s; anything in 'booking' this long died.
const STUCK_BOOKING_MINUTES = 15;

function isAuthorized(request: Request) {
  if (syncSecret) {
    return isValidWebhookSecret(request.headers.get("x-bobgo-sync-secret") ?? "", syncSecret);
  }
  try {
    return isValidWebhookSecret(getBearerToken(request), supabaseServiceRoleKey);
  } catch (_) {
    return false;
  }
}

function minutesAgo(minutes: number) {
  return new Date(Date.now() - minutes * 60 * 1000).toISOString();
}

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, { status: 405 });
    }
    if (!isAuthorized(request)) return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    if (!isBobGoConfigured()) return jsonResponse({ ok: true, skipped: "bobgo_not_configured" });

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // 1. Tracking backstop.
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

    // 2. Paid but never booked (or failed) - only orders still 'paid'.
    const { data: unbooked } = await admin
      .from("orders")
      .select(
        "id, shipping_method, bobgo_quote_id, bobgo_provider_slug, bobgo_service_level_code, bobgo_shipment_id",
      )
      .eq("shipping_method", "bobgo_door_to_door")
      .eq("status", "paid")
      .in("bobgo_booking_state", ["not_requested", "failed"])
      .is("bobgo_shipment_id", null)
      .or(`paid_at.is.null,paid_at.lte.${minutesAgo(BOOKING_GRACE_MINUTES)}`)
      .lt("bobgo_booking_attempts", MAX_BOOKING_ATTEMPTS)
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

    // 3. Stuck in 'booking'.
    const adopted: string[] = [];
    const stuckBookings: string[] = [];
    const { data: stuck } = await admin
      .from("orders")
      .select("id, bobgo_booking_attempts")
      .eq("shipping_method", "bobgo_door_to_door")
      .eq("bobgo_booking_state", "booking")
      .is("bobgo_shipment_id", null)
      .or(`bobgo_booking_started_at.is.null,bobgo_booking_started_at.lte.${minutesAgo(STUCK_BOOKING_MINUTES)}`)
      .limit(BOOK_BATCH);
    for (const order of stuck ?? []) {
      const outcome = await reconcileStuckBobGoBooking(admin, order);
      if (outcome === "adopted") adopted.push(order.id as string);
      else if (outcome !== "cancelled_after_refund") stuckBookings.push(order.id as string);
    }

    // Admin visibility: paid orders that ran out of automatic attempts.
    const { data: exhausted } = await admin
      .from("orders")
      .select("id")
      .eq("shipping_method", "bobgo_door_to_door")
      .eq("status", "paid")
      .eq("bobgo_booking_state", "failed")
      .gte("bobgo_booking_attempts", MAX_BOOKING_ATTEMPTS)
      .limit(50);
    const needsAttention = [
      ...stuckBookings,
      ...(exhausted ?? []).map((row: { id: string }) => row.id),
    ];
    if (needsAttention.length > 0) {
      console.error(`[bobgo] orders needing admin attention: ${needsAttention.join(", ")}`);
    }

    return jsonResponse({
      ok: true,
      tracked,
      trackFailures,
      booked,
      bookFailures,
      adopted,
      needsAttention,
    });
  } catch (error) {
    console.error("[bobgo-sync-tracking] failed", error);
    return jsonResponse({ error: "Sync failed." }, { status: 500 });
  }
});
