import { describe, expect, it } from "vitest";

import { isBlackFridayActive } from "./format";

describe("Black Friday window (South African time)", () => {
  it("starts at midnight on Friday 27 November", () => {
    expect(isBlackFridayActive(new Date("2026-11-26T21:59:59Z"))).toBe(false);
    expect(isBlackFridayActive(new Date("2026-11-26T22:00:00Z"))).toBe(true);
  });

  it("switches off at midnight after Monday 30 November", () => {
    expect(isBlackFridayActive(new Date("2026-11-30T21:59:59Z"))).toBe(true);
    expect(isBlackFridayActive(new Date("2026-11-30T22:00:00Z"))).toBe(false);
  });
});
