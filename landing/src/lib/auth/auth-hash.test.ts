import { describe, expect, it } from "vitest";

import { parseAuthHash, readSessionAuthMethods } from "./auth-hash";

function fakeJwt(payload: object) {
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({ alg: "HS256" })}.${encode(payload)}.signature`;
}

describe("auth hash links", () => {
  it("reads a recovery session from the fragment", () => {
    expect(parseAuthHash("#access_token=a&refresh_token=r&type=recovery&expires_in=3600")).toEqual({
      kind: "session",
      accessToken: "a",
      refreshToken: "r",
      type: "recovery",
    });
  });

  it("reports expired links as errors", () => {
    expect(
      parseAuthHash("error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid"),
    ).toEqual({ kind: "error", type: null });
  });

  it("ignores fragments that aren't auth links", () => {
    expect(parseAuthHash("#reviews")).toBeNull();
    expect(parseAuthHash("access_token=a&type=recovery")).toBeNull();
  });

  it("reads the sign-in methods from an access token", () => {
    expect(readSessionAuthMethods(fakeJwt({ amr: [{ method: "recovery", timestamp: 1 }] }))).toEqual([
      "recovery",
    ]);
    expect(readSessionAuthMethods("not-a-jwt")).toEqual([]);
  });
});
