import { buildOrderTrackingUpdate } from "./bobgo-tracking.mjs";

// deno-lint-ignore no-explicit-any
type AdminClient = any;

export const BOBGO_ORDER_TRACKING_COLUMNS =
  "id, tracking_number, tracking_url, bobgo_shipment_id, bobgo_status, bobgo_last_event_at, bobgo_booking_state";

/**
 * Applies a tracking snapshot to an order. Returns true when the order row
 * changed. Stale/out-of-order events are ignored (see buildOrderTrackingUpdate).
 */
export async function applyBobGoTrackingSnapshot(
  admin: AdminClient,
  order: { id: string; bobgo_status: string | null; bobgo_last_event_at: string | null },
  // deno-lint-ignore no-explicit-any
  snapshot: any,
) {
  const update = buildOrderTrackingUpdate(order, snapshot);
  if (!update) return false;
  const { error } = await admin.from("orders").update(update).eq("id", order.id);
  if (error) throw new Error(`Unable to save Bob Go tracking: ${error.message}`);
  return true;
}
