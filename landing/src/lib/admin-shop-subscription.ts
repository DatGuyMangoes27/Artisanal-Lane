import { isVendorSubscriptionActive } from "@/lib/marketplace/vendor-utils";

export type ShopSubscriptionFilter = "subscribed" | "not-subscribed" | "payment-late";

export type SubscriptionRow = {
  vendor_id: string;
  status: string | null;
  current_period_end: string | null;
};

export function parseShopSubscriptionFilter(
  value: string | null | undefined,
): ShopSubscriptionFilter | "" {
  return value === "subscribed" || value === "not-subscribed" || value === "payment-late"
    ? value
    : "";
}

/** Vendor ids with a currently active subscription (same rule as the vendor app). */
export function activeSubscriptionVendorIds(rows: SubscriptionRow[]): Set<string> {
  const active = new Set<string>();
  for (const row of rows) {
    if (
      isVendorSubscriptionActive({
        status: row.status,
        currentPeriodEnd: row.current_period_end,
      })
    ) {
      active.add(row.vendor_id);
    }
  }
  return active;
}

/**
 * Vendor ids whose recurring subscription is still marked active but whose
 * payment is past the paid-through date and the grace period: PayFast has not
 * charged them (paused subscription, expired card). Their shop is already
 * hidden; this lets the admin tell them apart from shops that never paid.
 */
export function lateSubscriptionVendorIds(rows: SubscriptionRow[]): Set<string> {
  const late = new Set<string>();
  for (const row of rows) {
    const status = (row.status ?? "").toLowerCase();
    if (
      (status === "active" || status === "past_due") &&
      row.current_period_end != null &&
      !isVendorSubscriptionActive({ status: row.status, currentPeriodEnd: row.current_period_end })
    ) {
      late.add(row.vendor_id);
    }
  }
  return late;
}

export function countBySubscription<T extends { subscribed: boolean; paymentLate?: boolean }>(
  items: T[],
) {
  let subscribed = 0;
  let paymentLate = 0;
  for (const item of items) {
    if (item.subscribed) subscribed += 1;
    if (item.paymentLate) paymentLate += 1;
  }
  return { subscribed, notSubscribed: items.length - subscribed, paymentLate, all: items.length };
}

export function filterBySubscription<T extends { subscribed: boolean; paymentLate?: boolean }>(
  items: T[],
  filter: ShopSubscriptionFilter | "" | undefined,
): T[] {
  if (filter === "subscribed") return items.filter((item) => item.subscribed);
  if (filter === "not-subscribed") return items.filter((item) => !item.subscribed);
  if (filter === "payment-late") return items.filter((item) => item.paymentLate === true);
  return items;
}
