import { describe, expect, it } from "vitest";

import {
  getPasswordRecoveryRedirectUrl,
  getPasswordRecoveryRequestOrigin,
  validateRecoveryPassword,
} from "./password-recovery";

describe("password recovery helpers", () => {
  it("builds the recovery callback on the current origin", () => {
    expect(
      getPasswordRecoveryRedirectUrl("https://artisanlanesa.co.za/vendor"),
    ).toBe("https://artisanlanesa.co.za/auth/callback");
  });

  it("uses Netlify's forwarded public origin for callback redirects", () => {
    const headers = new Headers({
      host: "main--artisanlane.netlify.app",
      "x-forwarded-host": "artisanlanesa.co.za",
      "x-forwarded-proto": "https",
    });

    expect(
      getPasswordRecoveryRequestOrigin(
        "https://main--artisanlane.netlify.app/auth/callback?code=test",
        headers,
      ),
    ).toBe("https://artisanlanesa.co.za");
  });

  it("requires an eight character password", () => {
    expect(validateRecoveryPassword("short", "short")).toBe(
      "Use at least 8 characters for your new password.",
    );
  });

  it("requires matching passwords", () => {
    expect(validateRecoveryPassword("new-password", "different-password")).toBe(
      "The passwords do not match.",
    );
  });

  it("accepts a valid matching password", () => {
    expect(validateRecoveryPassword("new-password", "new-password")).toBeNull();
  });
});
