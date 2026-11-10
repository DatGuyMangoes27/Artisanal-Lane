import { describe, expect, it } from "vitest";

import { summarisePurchase } from "./purchase-summary";

describe("summarisePurchase", () => {
  it("adds products and delivery across a several-shop checkout", () => {
    expect(
      summarisePurchase([
        { id: "a", status: "paid", total: "250.00", shipping_cost: "89.00", order_items: [{ product_id: "p1", quantity: 2 }] },
        { id: "b", status: "pending", total: 120, shipping_cost: 0, order_items: [{ product_id: "p2", quantity: 1 }] },
      ]),
    ).toEqual({ value: 459, contentIds: ["p1", "p2"], numItems: 3 });
  });

  it("ignores cancelled orders and empty totals", () => {
    expect(summarisePurchase([{ id: "a", status: "cancelled", total: 100, shipping_cost: 0 }])).toBeNull();
    expect(summarisePurchase([])).toBeNull();
  });
});
