import { isVendorSubscriptionActive } from "@/lib/marketplace/vendor-utils";

export type ShopSubscriptionFilter = "subscribed" | "not-subscribed";

export type SubscriptionRow = {
  vendor_id: string;
  status: string | null;
  current_period_end: string | null;
};

export function parseShopSubscriptionFilter(
  value: string | null | undefined,
): ShopSubscriptionFilter | "" {
  return value === "subscribed" || value === "not-subscribed" ? value : "";
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

export function countBySubscription<T extends { subscribed: boolean }>(items: T[]) {
  let subscribed = 0;
  for (const item of items) {
    if (item.subscribed) subscribed += 1;
  }
  return { subscribed, notSubscribed: items.length - subscribed, all: items.length };
}

export function filterBySubscription<T extends { subscribed: boolean }>(
  items: T[],
  filter: ShopSubscriptionFilter | "" | undefined,
): T[] {
  if (filter === "subscribed") return items.filter((item) => item.subscribed);
  if (filter === "not-subscribed") return items.filter((item) => !item.subscribed);
  return items;
}
