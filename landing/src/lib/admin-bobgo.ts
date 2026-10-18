import "server-only";

import { bobGoAttentionReason, type BobGoAttentionRow } from "@/lib/admin-bobgo-rules";
import { createAdminClient } from "@/lib/supabase/admin";

const BASE_COLUMNS =
  "id, shop_id, status, shipping_cost, paid_at, created_at, tracking_number, bobgo_booking_state, bobgo_booking_error, bobgo_charged_amount, bobgo_shipment_id";
// Added by 20260929120000_bobgo_tracking_and_cancellation.sql.
const TRACKING_COLUMNS = "bobgo_cancel_error, bobgo_booking_attempts";

/**
 * Bob Go orders an admin must look at: failed or stuck courier bookings,
 * courier refusals, failed cancellations after a refund, and courier charges
 * above what the buyer paid for shipping.
 */
export async function listBobGoAttentionOrders(now = new Date()) {
  const admin = createAdminClient();
  const query = (columns: string) =>
    admin
      .from("orders")
      .select(`${columns}, shops(name)`)
      .eq("shipping_method", "bobgo_door_to_door")
      .order("created_at", { ascending: false })
      .limit(300);

  let { data, error } = await query(`${BASE_COLUMNS}, ${TRACKING_COLUMNS}`);
  if (error) {
    // Tracking migration not applied yet: fall back to the foundation columns.
    ({ data, error } = await query(BASE_COLUMNS));
  }
  if (error || !data) return [];

  return (data as unknown as Array<BobGoAttentionRow & { shops?: { name?: string } | Array<{ name?: string }> | null }>)
    .map((row) => {
      const shop = Array.isArray(row.shops) ? row.shops[0] : row.shops;
      return { ...row, shopName: shop?.name ?? null, reason: bobGoAttentionReason(row, now) };
    })
    .filter((row) => row.reason != null);
}
