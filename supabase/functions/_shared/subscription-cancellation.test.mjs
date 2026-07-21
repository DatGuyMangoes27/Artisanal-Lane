import test from "node:test";
import assert from "node:assert/strict";

import {
  getPayFastCancellationToken,
  hasPayFastBillingReference,
  isPayFastCancellationSuccess,
} from "./subscription-cancellation.mjs";

test("uses only the official PayFast token for cancellation", () => {
  assert.equal(
    getPayFastCancellationToken({
      payfast_token: "  token-123  ",
      payfast_subscription_id: "subscription-id-456",
    }),
    "token-123",
  );
  assert.equal(
    getPayFastCancellationToken({
      payfast_subscription_id: "subscription-id-456",
    }),
    null,
  );
});

test("distinguishes complimentary subscriptions from PayFast billing agreements", () => {
  assert.equal(
    hasPayFastBillingReference({
      status: "active",
      payfast_token: null,
      payfast_subscription_id: null,
      payfast_payment_id: null,
      checkout_reference: null,
    }),
    false,
  );
  assert.equal(
    hasPayFastBillingReference({
      payfast_token: null,
      payfast_subscription_id: "subscription-123",
    }),
    true,
  );
  assert.equal(
    hasPayFastBillingReference({
      payfast_payment_id: "payment-123",
    }),
    true,
  );
});

test("accepts the documented PayFast cancellation response", () => {
  assert.equal(
    isPayFastCancellationSuccess(true, {
      code: 200,
      status: "success",
      data: { response: true },
    }),
    true,
  );
});

test("rejects failed PayFast responses even when HTTP status is successful", () => {
  assert.equal(
    isPayFastCancellationSuccess(true, {
      code: 400,
      status: "failed",
      data: { response: false },
    }),
    false,
  );
  assert.equal(isPayFastCancellationSuccess(false, null), false);
});
