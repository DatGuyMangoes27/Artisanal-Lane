export type BobGoAttentionRow = {
  id: string;
  status: string;
  shipping_cost: number | string | null;
  paid_at: string | null;
  tracking_number?: string | null;
  bobgo_booking_state: string | null;
  bobgo_booking_error: string | null;
  bobgo_charged_amount: number | string | null;
  bobgo_shipment_id?: string | null;
  bobgo_cancel_error?: string | null;
  bobgo_booking_attempts?: number | null;
};

const STUCK_AFTER_MS = 20 * 60 * 1000;

/** Why an admin should look at this Bob Go order, or null when it is fine. */
export function bobGoAttentionReason(row: BobGoAttentionRow, now = new Date()): string | null {
  const paidAgo = row.paid_at ? now.getTime() - new Date(row.paid_at).getTime() : 0;

  if (row.bobgo_cancel_error) {
    return `Courier cancellation needs follow-up: ${row.bobgo_cancel_error}`;
  }
  if (row.status === "paid") {
    if (row.bobgo_booking_state === "failed") {
      const attempts = row.bobgo_booking_attempts ?? null;
      const prefix = attempts != null && attempts >= 5
        ? "Booking failed - automatic retries exhausted"
        : "Booking failed - retrying automatically";
      return `${prefix}${row.bobgo_booking_error ? `: ${row.bobgo_booking_error}` : ""}`;
    }
    if (row.bobgo_booking_state === "booking" && paidAgo > STUCK_AFTER_MS) {
      return "Stuck in 'booking' - check Bob Go for a shipment with this order id as reference";
    }
    if (row.bobgo_booking_state === "not_requested" && paidAgo > STUCK_AFTER_MS) {
      return "Paid but no courier booking attempted yet";
    }
  }
  if (row.bobgo_booking_state === "booked" && row.bobgo_booking_error) {
    return row.bobgo_booking_error;
  }
  const charged = Number(row.bobgo_charged_amount);
  const paid = Number(row.shipping_cost ?? 0);
  if (row.bobgo_charged_amount != null && Number.isFinite(charged) && charged - paid > 0.01) {
    return `Courier charged R${charged.toFixed(2)}, buyer paid R${paid.toFixed(2)} for shipping`;
  }
  return null;
}
