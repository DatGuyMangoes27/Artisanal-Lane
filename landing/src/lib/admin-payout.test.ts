import { describe, expect, it } from "vitest";

import {
  canAdminTriggerTradeSafePayout,
  tradeSafePayoutLabel,
} from "./admin-payout";

describe("admin TradeSafe payout controls", () => {
  it("allows an admin to release shipped, delivered, or locally completed escrow", () => {
    expect(canAdminTriggerTradeSafePayout({
      status: "shipped",
      paymentProvider: "tradesafe",
      paymentState: "FUNDS_RECEIVED",
      tradeSafeAllocationId: "allocation-1",
    })).toBe(true);

    expect(canAdminTriggerTradeSafePayout({
      status: "delivered",
      paymentProvider: "tradesafe",
      paymentState: "FUNDS_RECEIVED",
      tradeSafeAllocationId: "allocation-1",
    })).toBe(true);

    expect(canAdminTriggerTradeSafePayout({
      status: "completed",
      paymentProvider: "tradesafe",
      paymentState: "DELIVERED",
      tradeSafeAllocationId: "allocation-1",
    })).toBe(true);
  });

  it("hides payout controls after release or for ineligible orders", () => {
    expect(canAdminTriggerTradeSafePayout({
      status: "completed",
      paymentProvider: "tradesafe",
      paymentState: "FUNDS_RELEASED",
      tradeSafeAllocationId: "allocation-1",
    })).toBe(false);

    expect(canAdminTriggerTradeSafePayout({
      status: "paid",
      paymentProvider: "tradesafe",
      paymentState: "FUNDS_RECEIVED",
      tradeSafeAllocationId: "allocation-1",
    })).toBe(false);

    expect(canAdminTriggerTradeSafePayout({
      status: "delivered",
      paymentProvider: "tradesafe",
      paymentState: "REFUNDED",
      tradeSafeAllocationId: "allocation-1",
    })).toBe(false);
  });

  it("uses payout wording that distinguishes instruction from settlement", () => {
    expect(tradeSafePayoutLabel("FUNDS_RECEIVED")).toBe("Held in escrow");
    expect(tradeSafePayoutLabel("DELIVERED")).toBe("Payout instructed");
    expect(tradeSafePayoutLabel("FUNDS_RELEASED")).toBe("Released");
  });
});
