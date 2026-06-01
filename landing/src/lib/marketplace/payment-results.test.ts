import { describe, expect, it } from "vitest";

import { getPaymentResultOrderHref, paymentResultStatusCopy } from "./payment-results";

describe("payment result helpers", () => {
  it("links buyers back to the order when a result page has an order id", () => {
    expect(getPaymentResultOrderHref(" order-123 ")).toBe("/account/orders/order-123");
    expect(getPaymentResultOrderHref("")).toBeNull();
    expect(getPaymentResultOrderHref(null)).toBeNull();
  });

  it("uses clear buyer-facing payment result copy", () => {
    expect(paymentResultStatusCopy("success").title).toBe("Thanks, your order is being processed.");
    expect(paymentResultStatusCopy("error").primaryActionHref).toBe("/cart");
  });
});
