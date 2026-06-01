import { describe, expect, it } from "vitest";

import {
  formatVendorStatus,
  getVendorSetupStatus,
  isVendorPayoutReady,
  isVendorShopProfileComplete,
  isVendorSubscriptionActive,
  parseCurrencyInput,
  parseListInput,
} from "./vendor-utils";

describe("vendor utility helpers", () => {
  it("treats active subscriptions and paid-through cancellations as active", () => {
    expect(isVendorSubscriptionActive({ status: "active", currentPeriodEnd: null })).toBe(true);
    expect(
      isVendorSubscriptionActive({
        status: "cancelled",
        currentPeriodEnd: new Date(Date.now() + 86_400_000).toISOString(),
      }),
    ).toBe(true);
    expect(
      isVendorSubscriptionActive({
        status: "cancelled",
        currentPeriodEnd: new Date(Date.now() - 86_400_000).toISOString(),
      }),
    ).toBe(false);
  });

  it("requires complete payout details before products can be added", () => {
    expect(
      isVendorPayoutReady({
        accountHolderName: "Clay Studio",
        bankName: "FNB",
        accountNumber: "123",
        branchCode: "250655",
        accountType: "CURRENT",
        registeredPhone: "0820000000",
        registeredEmail: "seller@example.com",
        identityNumber: "9001015009087",
        verificationStatus: "verified",
      }),
    ).toBe(true);
    expect(isVendorPayoutReady({ verificationStatus: "verified" })).toBe(false);
  });

  it("summarises setup gates for the dashboard", () => {
    expect(
      getVendorSetupStatus({
        hasShop: true,
        payoutReady: true,
        subscriptionActive: true,
      }),
    ).toEqual({
      canAddProducts: true,
      missingSteps: [],
    });

    expect(
      getVendorSetupStatus({
        hasShop: false,
        payoutReady: false,
        subscriptionActive: false,
      }),
    ).toEqual({
      canAddProducts: false,
      missingSteps: ["Shop profile", "Payout details", "Subscription"],
    });
  });

  it("requires basic public shop details before marking the shop profile complete", () => {
    expect(
      isVendorShopProfileComplete({
        name: "Clay House",
        bio: "Hand-thrown ceramics.",
        location: "Cape Town",
        shippingOptions: [{ key: "pargo" }],
      }),
    ).toBe(true);
    expect(
      isVendorShopProfileComplete({
        name: "Clay House",
        bio: "",
        location: "Cape Town",
        shippingOptions: [{ key: "pargo" }],
      }),
    ).toBe(false);
  });

  it("parses money and list inputs from forms", () => {
    expect(parseCurrencyInput("R 1,250.50")).toBe(1250.5);
    expect(parseCurrencyInput("")).toBe(0);
    expect(parseListInput("linen, clay\nwood")).toEqual(["linen", "clay", "wood"]);
  });

  it("formats machine statuses for display", () => {
    expect(formatVendorStatus("awaiting_payment")).toBe("Awaiting payment");
    expect(formatVendorStatus(null)).toBe("Unknown");
  });
});
