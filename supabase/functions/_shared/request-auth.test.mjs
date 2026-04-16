import test from "node:test";
import assert from "node:assert/strict";

import {
  normalizeRequestUserId,
  resolveRequestUserId,
} from "./request-auth.mjs";

test("normalizeRequestUserId trims and accepts non-empty ids", () => {
  assert.equal(normalizeRequestUserId("  user-1  "), "user-1");
  assert.equal(normalizeRequestUserId(""), null);
  assert.equal(normalizeRequestUserId("   "), null);
  assert.equal(normalizeRequestUserId(undefined), null);
});

test("resolveRequestUserId prefers resolved JWT user when available", () => {
  assert.equal(
    resolveRequestUserId({
      requestUserId: "body-user",
      resolvedUserId: "jwt-user",
    }),
    "jwt-user",
  );
});

test("resolveRequestUserId falls back to app-provided user id", () => {
  assert.equal(
    resolveRequestUserId({
      requestUserId: "body-user",
      resolvedUserId: null,
    }),
    "body-user",
  );
});
