import { describe, expect, it } from "vitest";

import {
  getAccountHomeHref,
  getLoginIntentCopy,
  getLoginRedirectForIntent,
  normalizeAccountRole,
} from "./account-routing";

describe("account routing helpers", () => {
  it("routes signed-in users to the correct account area by role", () => {
    expect(getAccountHomeHref("admin")).toBe("/admin");
    expect(getAccountHomeHref("vendor")).toBe("/vendor");
    expect(getAccountHomeHref("buyer")).toBe("/account");
    expect(getAccountHomeHref(null)).toBe("/login");
  });

  it("normalizes unknown roles to buyer", () => {
    expect(normalizeAccountRole("admin")).toBe("admin");
    expect(normalizeAccountRole("vendor")).toBe("vendor");
    expect(normalizeAccountRole("something-else")).toBe("buyer");
  });

  it("uses login intent to choose default redirect and copy", () => {
    expect(getLoginRedirectForIntent("vendor")).toBe("/vendor");
    expect(getLoginRedirectForIntent("buyer")).toBe("/shop");
    expect(getLoginIntentCopy("vendor").title).toBe("Vendor Sign In");
  });
});
