// Idempotent Bob Go shipment booking for a paid order.
//
// Used by tradesafe-callback (first attempt), bobgo-shipment (manual retry) and
// bobgo-sync-tracking (sweep for reconciled/failed orders). The claim update is
// a compare-and-set on bobgo_booking_state so concurrent callers cannot both
// book a courier.

import { createBobGoShipment } from "./bobgo.ts";

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
};

export type BookingResult =
  | { outcome: "skipped"; reason: string }
  | { outcome: "already_claimed" }
  | { outcome: "booked"; shipmentId: string; trackingReference: string | null }
  | { outcome: "failed"; error: string };

export function isBobGoBookable(order: BobGoBookableOrder) {
  return order.shipping_method === "bobgo_door_to_door" &&
    !order.bobgo_shipment_id &&
    Boolean(order.bobgo_quote_id) &&
    Boolean(order.bobgo_provider_slug) &&
    Boolean(order.bobgo_service_level_code);
}

export async function bookBobGoShipmentForOrder(
  admin: AdminClient,
  order: BobGoBookableOrder,
  deps: BookingDeps = { createShipment: createBobGoShipment },
): Promise<BookingResult> {
  if (!isBobGoBookable(order)) {
    return { outcome: "skipped", reason: "not_a_bookable_bobgo_order" };
  }

  const { data: claimed } = await admin
    .from("orders")
    .update({ bobgo_booking_state: "booking", bobgo_booking_error: null })
    .eq("id", order.id)
    .in("bobgo_booking_state", ["not_requested", "failed"])
    .is("bobgo_shipment_id", null)
    .select("id, bobgo_booking_attempts")
    .maybeSingle();

  if (!claimed) return { outcome: "already_claimed" };

  try {
    const { data: quote, error: quoteError } = await admin
      .from("bobgo_shipping_quotes")
      .select("request_snapshot")
      .eq("id", order.bobgo_quote_id)
      .single();
    if (quoteError || !quote) {
      throw new Error("The saved Bob Go shipment quote could not be loaded.");
    }

    const shipment = await deps.createShipment({
      orderId: order.id,
      providerSlug: order.bobgo_provider_slug as string,
      serviceLevelCode: order.bobgo_service_level_code as string,
      rateRequestSnapshot: quote.request_snapshot,
    });

    const now = new Date().toISOString();
    const { error: saveError } = await admin
      .from("orders")
      .update({
        bobgo_shipment_id: shipment.shipmentId,
        bobgo_booking_state: "booked",
        bobgo_booked_at: now,
        bobgo_status: shipment.status,
        bobgo_charged_amount: shipment.chargedAmount,
        bobgo_tracking_url: shipment.trackingUrl ?? null,
        tracking_number: shipment.trackingReference,
        ...(shipment.trackingUrl ? { tracking_url: shipment.trackingUrl } : {}),
        bobgo_booking_attempts: Number(claimed.bobgo_booking_attempts ?? 0) + 1,
      })
      .eq("id", order.id);
    if (saveError) {
      // The courier IS booked. Leave the order in 'booking' so nothing retries
      // blindly, and make the shipment id discoverable in logs for an admin.
      console.error(
        `[bobgo] order ${order.id} booked shipment ${shipment.shipmentId} but saving failed: ${saveError.message}`,
      );
      return { outcome: "failed", error: `Shipment ${shipment.shipmentId} booked but not saved.` };
    }

    return {
      outcome: "booked",
      shipmentId: shipment.shipmentId,
      trackingReference: shipment.trackingReference,
    };
  } catch (bookingError) {
    const message = bookingError instanceof Error ? bookingError.message : "Bob Go booking failed.";
    console.error(`[bobgo] order ${order.id} booking failed: ${message}`);
    await admin
      .from("orders")
      .update({
        bobgo_booking_state: "failed",
        bobgo_booking_error: message,
        bobgo_booking_attempts: Number(claimed.bobgo_booking_attempts ?? 0) + 1,
      })
      .eq("id", order.id);
    return { outcome: "failed", error: message };
  }
}
