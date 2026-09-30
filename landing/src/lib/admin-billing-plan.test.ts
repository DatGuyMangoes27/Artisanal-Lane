import { describe, expect, it } from "vitest";

import {
  APPROVED_CHANGES,
  addMonthsClamped,
  computeTarget,
  isFoundersApplied,
  validateCustomChange,
} from "./admin-billing-plan";

describe("addMonthsClamped", () => {
  it("adds a plain month", () => {
    expect(addMonthsClamped("2026-09-30", 1)).toBe("2026-10-30");
  });
  it("clamps to month end", () => {
    expect(addMonthsClamped("2026-01-31", 1)).toBe("2026-02-28");
    expect(addMonthsClamped("2028-01-31", 1)).toBe("2028-02-29");
    expect(addMonthsClamped("2026-10-31", 1)).toBe("2026-11-30");
  });
  it("rolls over the year", () => {
    expect(addMonthsClamped("2026-12-15", 1)).toBe("2027-01-15");
  });
});

describe("computeTarget", () => {
  const base = {
    payfastRunDate: "2026-10-30",
    startedAt: null,
    today: "2026-09-30",
  };
  it("r199-from-next keeps run date", () => {
    expect(computeTarget("r199-from-next", base)).toEqual({
      amount: 199,
      runDate: null,
      flag: null,
    });
  });
  it("free month adds a month to the PayFast run date", () => {
    expect(computeTarget("free-month-then-r199", base)?.runDate).toBe(
      "2026-11-30",
    );
    expect(() =>
      computeTarget("free-month-then-r199", { ...base, payfastRunDate: null }),
    ).toThrow();
  });
  it("one month from signup uses started_at when in the future", () => {
    const t = computeTarget("one-month-from-signup-then-r199", {
      ...base,
      startedAt: "2026-09-20T10:00:00Z",
    });
    expect(t?.runDate).toBe("2026-10-20");
    expect(t?.flag).toBeNull();
  });
  it("flags when signup + 1 month is not in the future", () => {
    const t = computeTarget("one-month-from-signup-then-r199", {
      ...base,
      startedAt: "2026-08-15T10:00:00Z",
    });
    expect(t?.runDate).toBeNull();
    expect(t?.flag).toContain("not in the future");
  });
  it("reinstate has no target", () => {
    expect(computeTarget("reinstate-6-months", base)).toBeNull();
  });
});

describe("validateCustomChange", () => {
  const today = "2026-09-30";
  const input = (o: Partial<Parameters<typeof validateCustomChange>[0]>) => ({
    email: "a@b.co",
    amount: "",
    runDate: "",
    note: "",
    ...o,
  });
  it("requires amount or date", () => {
    expect(validateCustomChange(input({}), today).ok).toBe(false);
  });
  it("accepts valid input", () => {
    expect(
      validateCustomChange(
        input({ email: " A@b.co ", amount: "199", runDate: "2026-10-31", note: " hi " }),
        today,
      ),
    ).toEqual({
      ok: true,
      value: { email: "a@b.co", amount: 199, runDate: "2026-10-31", note: "hi" },
    });
  });
  it("rejects bad values", () => {
    expect(validateCustomChange(input({ runDate: "2026-09-30" }), today).ok).toBe(false);
    expect(validateCustomChange(input({ amount: "-5" }), today).ok).toBe(false);
    expect(validateCustomChange(input({ email: "nope", amount: "5" }), today).ok).toBe(false);
    expect(validateCustomChange(input({ runDate: "2026-02-30" }), today).ok).toBe(false);
  });
});

describe("plan data", () => {
  it("has unique lowercase emails", () => {
    const emails = APPROVED_CHANGES.map((c) => c.email);
    expect(new Set(emails).size).toBe(emails.length);
    expect(emails.every((e) => e === e.toLowerCase())).toBe(true);
  });
  it("detects applied rows", () => {
    expect(isFoundersApplied({ amount: 199, plan_code: "founders-199" })).toBe(true);
    expect(isFoundersApplied({ amount: 349, plan_code: "founders-199" })).toBe(false);
  });
});
