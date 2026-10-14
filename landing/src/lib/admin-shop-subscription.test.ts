import { describe, expect, it } from "vitest";

import {
  activeSubscriptionVendorIds,
  countBySubscription,
  filterBySubscription,
  parseShopSubscriptionFilter,
} from "./admin-shop-subscription";

const future = new Date(Date.now() + 86_400_000).toISOString();
const past = new Date(Date.now() - 10 * 86_400_000).toISOString();
// Inside the 5-day grace for a late or failed recurring payment.
const lateWithinGrace = new Date(Date.now() - 86_400_000).toISOString();

describe("admin shop subscription split", () => {
  it("treats active (with payment grace), in-period cancelled as subscribed and the rest as not", () => {
    const ids = activeSubscriptionVendorIds([
      { vendor_id: "a", status: "active", current_period_end: future },
      { vendor_id: "b", status: "active", current_period_end: past },
      { vendor_id: "c", status: "cancelled", current_period_end: future },
      { vendor_id: "d", status: "cancelled", current_period_end: past },
      { vendor_id: "e", status: "inactive", current_period_end: future },
      { vendor_id: "f", status: "past_due", current_period_end: future },
      { vendor_id: "g", status: "active", current_period_end: lateWithinGrace },
      { vendor_id: "h", status: "cancelled", current_period_end: lateWithinGrace },
    ]);
    expect([...ids].sort()).toEqual(["a", "c", "f", "g"]);
  });

  it("filters and counts", () => {
    const items = [
      { id: 1, subscribed: true },
      { id: 2, subscribed: false },
      { id: 3, subscribed: false },
    ];
    expect(countBySubscription(items)).toEqual({ all: 3, subscribed: 1, notSubscribed: 2 });
    expect(filterBySubscription(items, "subscribed")).toHaveLength(1);
    expect(filterBySubscription(items, "not-subscribed")).toHaveLength(2);
    expect(filterBySubscription(items, "")).toHaveLength(3);
  });

  it("parses the filter param defensively", () => {
    expect(parseShopSubscriptionFilter("subscribed")).toBe("subscribed");
    expect(parseShopSubscriptionFilter("bogus")).toBe("");
    expect(parseShopSubscriptionFilter(undefined)).toBe("");
  });
});
