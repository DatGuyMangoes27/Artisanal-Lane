import { describe, expect, it } from "vitest";

import {
  canOpenDisputeForOrderStatus,
  formatDisputeStatus,
  sanitizeDisputeReason,
} from "./disputes";

describe("buyer dispute helpers", () => {
  it("allows opening disputes only for shipped or delivered orders", () => {
    expect(canOpenDisputeForOrderStatus("shipped")).toBe(true);
    expect(canOpenDisputeForOrderStatus("delivered")).toBe(true);
    expect(canOpenDisputeForOrderStatus("paid")).toBe(false);
    expect(canOpenDisputeForOrderStatus("completed")).toBe(false);
    expect(canOpenDisputeForOrderStatus("disputed")).toBe(false);
  });

  it("sanitizes dispute reasons", () => {
    expect(sanitizeDisputeReason("  Damaged on arrival  ")).toBe("Damaged on arrival");
    expect(sanitizeDisputeReason("   ")).toBeNull();
  });

  it("formats dispute status labels", () => {
    expect(formatDisputeStatus("investigating")).toBe("Investigating");
    expect(formatDisputeStatus(null)).toBe("Unknown");
  });
});
