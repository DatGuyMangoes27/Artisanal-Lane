// Buyer/vendor-facing helpers for Bob Go courier status. Mirrors the grouping in
// supabase/functions/_shared/bobgo-tracking.mjs (keep the two in sync).

export type BobGoStatusGroup =
  | "awaiting_collection"
  | "collected"
  | "in_transit"
  | "out_for_delivery"
  | "delivered"
  | "exception"
  | "returned"
  | "cancelled"
  | "unknown";

const groups: Array<[BobGoStatusGroup, string[]]> = [
  ["delivered", ["delivered", "collected-by-customer"]],
  ["cancelled", ["cancelled", "canceled", "shipment-cancelled"]],
  ["returned", ["returned", "returning", "return-to-sender", "returned-to-sender"]],
  ["exception", ["failed-delivery", "delivery-failed", "exception", "failed", "delayed", "lost", "damaged", "undeliverable", "collection-exception", "delivery-exception", "failed-collection"]],
  ["out_for_delivery", ["out-for-delivery", "with-delivery-courier", "out-for-delivery-attempt", "ready-for-pickup"]],
  ["in_transit", ["in-transit", "in-transit-to-destination", "at-hub", "at-destination-hub", "dispatched", "departed", "arrived"]],
  ["collected", ["collected", "picked-up", "pickup-complete", "collection-complete"]],
  ["awaiting_collection", ["submitted", "pending", "pending-collection", "collection-assigned", "collection-pending", "booked", "created", "confirmed", "ready-for-collection", "awaiting-collection"]],
];

const labels: Record<BobGoStatusGroup, string> = {
  awaiting_collection: "Booked - waiting for courier collection",
  collected: "Collected by the courier",
  in_transit: "On its way",
  out_for_delivery: "Out for delivery",
  delivered: "Delivered",
  exception: "Delivery problem - the courier will retry",
  returned: "Returning to the artisan",
  cancelled: "Courier booking cancelled",
  unknown: "In progress",
};

export function bobGoStatusGroup(status: string | null | undefined): BobGoStatusGroup {
  const normalized = (status ?? "").trim().toLowerCase().replace(/[_\s]+/g, "-");
  if (!normalized) return "unknown";
  return groups.find(([, values]) => values.includes(normalized))?.[0] ?? "unknown";
}

export function bobGoStatusLabel(status: string | null | undefined) {
  return labels[bobGoStatusGroup(status)];
}

/** Buyer-facing summary of the courier booking, or null for non-Bob Go orders. */
export function describeBobGoCourier(order: {
  shippingMethod: string | null;
  bobgoBookingState: string | null;
  bobgoStatus: string | null;
}): { headline: string; tone: "info" | "success" | "warning" } | null {
  if (order.shippingMethod !== "bobgo_door_to_door") return null;
  switch (order.bobgoBookingState) {
    case "booked":
      return {
        headline: bobGoStatusLabel(order.bobgoStatus),
        tone: bobGoStatusGroup(order.bobgoStatus) === "exception" ? "warning" : "success",
      };
    case "cancelled":
      return { headline: labels.cancelled, tone: "warning" };
    case "failed":
    case "booking":
    case "not_requested":
    default:
      return {
        headline: "We are arranging your courier. You will see tracking here once it is booked.",
        tone: "info",
      };
  }
}

export type QuoteEta = {
  etaFrom?: string | null;
  etaTo?: string | null;
  etaMinDays?: number | null;
  etaMaxDays?: number | null;
};

const dateFormat = new Intl.DateTimeFormat("en-ZA", { day: "numeric", month: "short" });

/** Human delivery estimate, or null when the courier did not supply one. */
export function formatRateEta(rate: QuoteEta): string | null {
  const from = rate.etaFrom ? new Date(rate.etaFrom) : null;
  const to = rate.etaTo ? new Date(rate.etaTo) : null;
  if (from && !Number.isNaN(from.getTime())) {
    if (to && !Number.isNaN(to.getTime()) && to.getTime() !== from.getTime()) {
      return `Estimated ${dateFormat.format(from)} - ${dateFormat.format(to)}`;
    }
    return `Estimated ${dateFormat.format(from)}`;
  }
  const min = rate.etaMinDays ?? null;
  const max = rate.etaMaxDays ?? null;
  if (min && max && min !== max) return `Estimated ${min}-${max} business days`;
  const days = max ?? min;
  if (days) return `Estimated ${days} business day${days === 1 ? "" : "s"}`;
  return null;
}

export function isBobGoQuoteExpired(expiresAt: string | null | undefined, now = Date.now()) {
  if (!expiresAt) return false;
  const expires = new Date(expiresAt).getTime();
  return Number.isNaN(expires) ? false : expires <= now;
}
