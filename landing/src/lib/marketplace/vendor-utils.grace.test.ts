import { describe, expect, it } from "vitest";

import {
  hasVendorSubscriptionPaymentIssue,
  isVendorSubscriptionActive,
} from "./vendor-utils";

const daysFromNow = (days: number) => new Date(Date.now() + days * 86_400_000).toISOString();

describe("subscription payment grace", () => {
  it("keeps a recurring subscription usable for 5 days after its paid-through date", () => {
    expect(isVendorSubscriptionActive({ status: "active", currentPeriodEnd: daysFromNow(-1) })).toBe(true);
    expect(isVendorSubscriptionActive({ status: "past_due", currentPeriodEnd: daysFromNow(-4) })).toBe(true);
    expect(isVendorSubscriptionActive({ status: "active", currentPeriodEnd: daysFromNow(-6) })).toBe(false);
  });

  it("ends a cancelled subscription at its paid-through date", () => {
    expect(isVendorSubscriptionActive({ status: "cancelled", currentPeriodEnd: daysFromNow(-1) })).toBe(false);
    expect(isVendorSubscriptionActive({ status: "cancelled", currentPeriodEnd: daysFromNow(3) })).toBe(true);
  });

  it("flags a payment issue only for a lapsed PayFast subscription", () => {
    const lapsed = { status: "active", currentPeriodEnd: daysFromNow(-1), hasPayFastToken: true };
    expect(hasVendorSubscriptionPaymentIssue(lapsed)).toBe(true);
    expect(hasVendorSubscriptionPaymentIssue({ ...lapsed, hasPayFastToken: false })).toBe(false);
    expect(hasVendorSubscriptionPaymentIssue({ ...lapsed, currentPeriodEnd: daysFromNow(10) })).toBe(false);
    // A renewal notice a few hours late isn't flagged yet.
    expect(
      hasVendorSubscriptionPaymentIssue({ ...lapsed, currentPeriodEnd: new Date(Date.now() - 3_600_000).toISOString() }),
    ).toBe(false);
    expect(hasVendorSubscriptionPaymentIssue({ ...lapsed, status: "cancelled" })).toBe(false);
  });
});
