import { describe, expect, it } from "vitest";

import { buildPayFastCardUpdateUrl } from "./payfast-card-update";

describe("buildPayFastCardUpdateUrl", () => {
  it("builds the secure PayFast recurring-card update link", () => {
    expect(buildPayFastCardUpdateUrl("subscription-token")).toBe(
      "https://www.payfast.co.za/eng/recurring/update/subscription-token?return=https%3A%2F%2Fartisanlanesa.co.za%2Fvendor%2Fprofile%2Fsubscription",
    );
  });

  it("rejects an empty token", () => {
    expect(() => buildPayFastCardUpdateUrl("  ")).toThrow(
      "A PayFast subscription token is required.",
    );
  });
});
