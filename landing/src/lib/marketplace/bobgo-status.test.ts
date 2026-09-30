import { describe, expect, it } from "vitest";

import {
  bobGoStatusGroup,
  bobGoStatusLabel,
  describeBobGoCourier,
  formatRateEta,
  isBobGoQuoteExpired,
} from "./bobgo-status";

describe("Bob Go status helpers", () => {
  it("groups statuses regardless of casing and separators", () => {
    expect(bobGoStatusGroup("In_Transit")).toBe("in_transit");
    expect(bobGoStatusGroup("out for delivery")).toBe("out_for_delivery");
    expect(bobGoStatusGroup("mystery")).toBe("unknown");
    expect(bobGoStatusLabel("delivered")).toBe("Delivered");
    expect(bobGoStatusLabel(null)).toBe("In progress");
  });

  it("only describes Bob Go orders", () => {
    expect(
      describeBobGoCourier({ shippingMethod: "pargo", bobgoBookingState: null, bobgoStatus: null }),
    ).toBeNull();
    expect(
      describeBobGoCourier({
        shippingMethod: "bobgo_door_to_door",
        bobgoBookingState: "booked",
        bobgoStatus: "in-transit",
      }),
    ).toEqual({ headline: "On its way", tone: "success" });
    expect(
      describeBobGoCourier({
        shippingMethod: "bobgo_door_to_door",
        bobgoBookingState: "failed",
        bobgoStatus: null,
      })?.tone,
    ).toBe("info");
    expect(
      describeBobGoCourier({
        shippingMethod: "bobgo_door_to_door",
        bobgoBookingState: "cancelled",
        bobgoStatus: "cancelled",
      })?.headline,
    ).toBe("Courier booking cancelled");
  });

  it("formats delivery estimates", () => {
    expect(formatRateEta({})).toBeNull();
    expect(formatRateEta({ etaMinDays: 2, etaMaxDays: 4 })).toBe("Estimated 2-4 business days");
    expect(formatRateEta({ etaMaxDays: 1 })).toBe("Estimated 1 business day");
    expect(formatRateEta({ etaFrom: "2026-10-01T00:00:00Z" })).toMatch(/^Estimated /);
  });

  it("detects expired quotes", () => {
    const now = Date.parse("2026-09-29T12:00:00Z");
    expect(isBobGoQuoteExpired("2026-09-29T11:59:59Z", now)).toBe(true);
    expect(isBobGoQuoteExpired("2026-09-29T12:10:00Z", now)).toBe(false);
    expect(isBobGoQuoteExpired(null, now)).toBe(false);
  });
});
