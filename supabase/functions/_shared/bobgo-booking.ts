// Idempotent Bob Go shipment booking for a paid order.
//
// Used by tradesafe-callback (first attempt), bobgo-shipment (manual retry) and
// bobgo-sync-tracking (sweep + stuck-booking reconciliation).
//
// Double-booking protection, in layers:
//   1. The claim is a compare-and-set (status = 'paid', booking state
//      not_requested|failed, no shipment id), so concurrent callers cannot both
//      book.
//   2. Bob Go has no idempotency key, so every attempt after the first looks the
//      order up on Bob Go first (custom reference = order id) and adopts an
//      existing live shipment instead of creating another one.
//   3. A crash between "Bob Go accepted" and "saved" leaves the order in
//      'booking'; that is never retried blindly - reconcileStuckBobGoBooking
//      only adopts a shipment it can find.
//   4. If the order was cancelled/refunded while the booking was in flight, the
//      fresh shipment is cancelled straight away.

import {
  BobGoApiError,
  type BobGoShipment,
  cancelBobGoShipment,
  createBobGoShipment,
  findBobGoShipmentForOrder,
} from "./bobgo.ts";

export type BobGoBookableOrder = {
  id: string;
  shipping_method: string | null;
  bobgo_quote_id: string | null;
  bobgo_provider_slug: string | null;
  bobgo_service_level_code: string | null;
  bobgo_shipment_id: string | null;
};

// Minimal surface of the supabase-js client we use (keeps the helper testable).
// deno-lint-ignore no-explicit-any
type AdminClient = any;

export type BookingDeps = {
  createShipment: typeof createBobGoShipment;
  findShipment: (orderId: string) => Promise<BobGoShipment | null>;
  cancelShipment: (trackingReference: string) => Promise<void>;
};

const defaultDeps: BookingDeps = {
  createShipment: createBobGoShipment,
  findShipment: findBobGoShipmentForOrder,
  cancelShipment: cancelBobGoShipment,
};

export type BookingResult =
  | { outcome: "skipped"; reason: string }
  | { outcome: "already_claimed" }
  | { outcome: "booked"; shipmentId: string; trackingReference: string | null; adopted: boolean }
  | { outcome: "cancelled_after_refund"; shipmentId: string }
  | { outcome: "failed"; error: string };

export function isBobGoBookable(order: BobGoBookableOrder) {
  return order.shipping_method === "bobgo_door_to_door" &&
    !order.bobgo_shipment_id &&
    Boolean(order.bobgo_quote_id) &&
    Boolean(order.bobgo_provider_slug) &&
    Boolean(order.bobgo_service_level_code);
}

function text(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function bookedUpdate(shipment: BobGoShipment, attempts: number) {
  return {
    bobgo_shipment_id: shipment.shipmentId,
    bobgo_booking_state: "booked",
    bobgo_booked_at: new Date().toISOString(),
    bobgo_booking_error: null,
    bobgo_status: shipment.status,
    ...(shipment.chargedAmount != null ? { bobgo_charged_amount: shipment.chargedAmount } : {}),
    bobgo_tracking_url: shipment.trackingUrl ?? null,
    tracking_number: shipment.trackingReference,
    ...(shipment.trackingUrl ? { tracking_url: shipment.trackingUrl } : {}),
    bobgo_booking_attempts: attempts,
  };
}

/**
 * Saves a booked shipment (compare-and-set on state 'booking') and, if the
 * order was cancelled meanwhile, cancels the shipment again.
 */
async function saveBookedShipment(
  admin: AdminClient,
  orderId: string,
  shipment: BobGoShipment,
  attempts: number,
  deps: BookingDeps,
  adopted: boolean,
): Promise<BookingResult> {
  const { data: saved, error: saveError } = await admin
    .from("orders")
    .update(bookedUpdate(shipment, attempts))
    .eq("id", orderId)
    .eq("bobgo_booking_state", "booking")
    .select("id, status")
    .maybeSingle();
  if (saveError || !saved) {
    // The courier IS booked. Leave the order in 'booking' so nothing retries
    // blindly; the sync job adopts it via the lookup, and the id is logged.
    console.error(
      `[bobgo] order ${orderId} booked shipment ${shipment.shipmentId} but saving failed: ${saveError?.message ?? "state changed"}`,
    );
    return { outcome: "failed", error: `Shipment ${shipment.shipmentId} booked but not saved.` };
  }

  if (saved.status === "cancelled") {
    // Refunded while we were booking: undo the courier booking.
    let cancelError: string | null = null;
    if (shipment.trackingReference) {
      try {
        await deps.cancelShipment(shipment.trackingReference);
      } catch (error) {
        cancelError = error instanceof Error ? error.message : "Bob Go cancellation failed.";
      }
    } else {
      cancelError = "No tracking reference to cancel the late booking with.";
    }
    await admin
      .from("orders")
      .update(
        cancelError
          ? { bobgo_cancel_error: `Booked after the order was cancelled: ${cancelError}` }
          : {
            bobgo_booking_state: "cancelled",
            bobgo_status: "cancelled",
            bobgo_cancelled_at: new Date().toISOString(),
            bobgo_cancel_error: null,
          },
      )
      .eq("id", orderId);
    console.error(
      `[bobgo] order ${orderId} was cancelled during booking; shipment ${shipment.shipmentId} cancel ${cancelError ? `failed: ${cancelError}` : "ok"}`,
    );
    return { outcome: "cancelled_after_refund", shipmentId: shipment.shipmentId };
  }

  return {
    outcome: "booked",
    shipmentId: shipment.shipmentId,
    trackingReference: shipment.trackingReference,
    adopted,
  };
}

export async function bookBobGoShipmentForOrder(
  admin: AdminClient,
  order: BobGoBookableOrder,
  deps: BookingDeps = defaultDeps,
): Promise<BookingResult> {
  if (!isBobGoBookable(order)) {
    return { outcome: "skipped", reason: "not_a_bookable_bobgo_order" };
  }

  const { data: claimed } = await admin
    .from("orders")
    .update({
      bobgo_booking_state: "booking",
      bobgo_booking_error: null,
      bobgo_booking_started_at: new Date().toISOString(),
    })
    .eq("id", order.id)
    .eq("status", "paid")
    .in("bobgo_booking_state", ["not_requested", "failed"])
    .is("bobgo_shipment_id", null)
    .select("id, bobgo_booking_attempts, shipping_address")
    .maybeSingle();

  if (!claimed) return { outcome: "already_claimed" };
  const previousAttempts = Number(claimed.bobgo_booking_attempts ?? 0);
  const attempts = previousAttempts + 1;

  try {
    const { data: quote, error: quoteError } = await admin
      .from("bobgo_shipping_quotes")
      .select("request_snapshot")
      .eq("id", order.bobgo_quote_id)
      .single();
    if (quoteError || !quote) {
      throw new Error("The saved Bob Go shipment quote could not be loaded.");
    }

    // A first attempt has never reached Bob Go, so there is nothing to find.
    let existing: BobGoShipment | null = null;
    if (previousAttempts > 0) {
      try {
        existing = await deps.findShipment(order.id);
      } catch (lookupError) {
        // A transient lookup failure must not turn into a blind second booking.
        if (!(lookupError instanceof BobGoApiError) || lookupError.ambiguous) throw lookupError;
        // A definite refusal (4xx) means the lookup is unsupported; booking is
        // still guarded by the claim above.
        console.error(`[bobgo] order ${order.id} shipment lookup refused: ${lookupError.message}`);
      }
    }

    const address = (claimed.shipping_address ?? {}) as Record<string, unknown>;
    const shipment = existing ?? await deps.createShipment({
      orderId: order.id,
      providerSlug: order.bobgo_provider_slug as string,
      serviceLevelCode: order.bobgo_service_level_code as string,
      rateRequestSnapshot: quote.request_snapshot,
      deliveryContact: { name: text(address.name), phone: text(address.phone) },
    });

    return await saveBookedShipment(admin, order.id, shipment, attempts, deps, existing != null);
  } catch (bookingError) {
    const message = bookingError instanceof Error ? bookingError.message : "Bob Go booking failed.";
    console.error(`[bobgo] order ${order.id} booking attempt ${attempts} failed: ${message}`);
    await admin
      .from("orders")
      .update({
        bobgo_booking_state: "failed",
        bobgo_booking_error: message.slice(0, 500),
        bobgo_booking_attempts: attempts,
      })
      .eq("id", order.id)
      .eq("bobgo_booking_state", "booking");
    return { outcome: "failed", error: message };
  }
}

/**
 * For an order left in 'booking' (the function died after calling Bob Go):
 * adopt the shipment if Bob Go has one for this order. Never creates one.
 */
export async function reconcileStuckBobGoBooking(
  admin: AdminClient,
  order: { id: string; bobgo_booking_attempts?: number | null },
  deps: BookingDeps = defaultDeps,
): Promise<"adopted" | "not_found" | "cancelled_after_refund" | "error"> {
  try {
    const shipment = await deps.findShipment(order.id);
    if (!shipment) return "not_found";
    const result = await saveBookedShipment(
      admin,
      order.id,
      shipment,
      Number(order.bobgo_booking_attempts ?? 0) + 1,
      deps,
      true,
    );
    if (result.outcome === "booked") return "adopted";
    if (result.outcome === "cancelled_after_refund") return "cancelled_after_refund";
    return "error";
  } catch (error) {
    console.error(
      `[bobgo] order ${order.id} stuck-booking lookup failed: ${error instanceof Error ? error.message : error}`,
    );
    return "error";
  }
}
