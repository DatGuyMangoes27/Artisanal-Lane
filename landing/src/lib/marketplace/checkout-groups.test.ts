import { describe, expect, it } from "vitest";

import {
  checkoutGroupStatusCopy,
  isFinalCheckoutGroupStatus,
  parseCheckoutGroupState,
  successPageHrefForGroup,
} from "./checkout-groups";

describe("several-shop checkout helpers", () => {
  it("reads a checkout-group-status answer", () => {
    expect(
      parseCheckoutGroupState({
        checkoutGroupId: "group-1",
        status: "awaiting_payment",
        orderIds: ["order-1", "order-2"],
        paidOrderIds: [],
        checkoutUrl: "https://pay.example/basket",
      }),
    ).toEqual({
      checkoutGroupId: "group-1",
      status: "awaiting_payment",
      orderIds: ["order-1", "order-2"],
      paidOrderIds: [],
      checkoutUrl: "https://pay.example/basket",
    });

    expect(
      parseCheckoutGroupState({ checkoutGroupId: "group-1", status: "funded", orderIds: ["order-1"], checkoutUrl: null }),
    ).toMatchObject({ status: "funded", paidOrderIds: [], checkoutUrl: null });
    expect(parseCheckoutGroupState({ error: "Checkout not found." })).toBeNull();
    expect(parseCheckoutGroupState({ checkoutGroupId: "group-1", status: "mystery" })).toBeNull();
  });

  it("stops waiting once the checkout is settled", () => {
    expect(isFinalCheckoutGroupStatus("awaiting_payment")).toBe(false);
    expect(isFinalCheckoutGroupStatus("funded")).toBe(true);
    expect(isFinalCheckoutGroupStatus("cancelled")).toBe(true);
    expect(isFinalCheckoutGroupStatus("needs_attention")).toBe(true);
  });

  it("explains what happened to the buyer's money", () => {
    expect(checkoutGroupStatusCopy("cancelled").body).toBe(
      "This checkout expired before payment. Nothing was charged to the shops; if you paid, the money is in your TradeSafe wallet and will be used on your next checkout.",
    );
    expect(checkoutGroupStatusCopy("needs_attention").body).toContain("nicky@artisanlanesa.com");
  });

  it("links the success page to the checkout", () => {
    expect(successPageHrefForGroup("group 1")).toBe("/payment/success?group=group%201");
  });
});
