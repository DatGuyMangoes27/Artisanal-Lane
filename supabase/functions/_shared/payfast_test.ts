import { assertEquals } from "jsr:@std/assert";

import { buildPayFastSubscriptionCheckoutUrl } from "./payfast.ts";

Deno.test("subscription checkout supports free-trial initial amount with recurring amount", () => {
  Deno.env.set("PAYFAST_MERCHANT_ID", "10000100");
  Deno.env.set("PAYFAST_MERCHANT_KEY", "46f0cd694581a");
  Deno.env.set("PAYFAST_PASSPHRASE", "test-passphrase");
  Deno.env.set("PAYFAST_SANDBOX", "true");

  const checkoutUrl = buildPayFastSubscriptionCheckoutUrl({
    amount: 0,
    recurringAmount: 349,
    itemName: "Artisan Lane Subscription",
    itemDescription: "Artisan subscription with first month free",
    reference: "artisan-subscription-vendor-1",
    vendorId: "vendor-1",
    checkoutReference: "checkout-1",
    email: "vendor@example.com",
    displayName: "Vendor Example",
    returnUrl: "https://artisanlanesa.co.za/vendor/subscription/success",
    cancelUrl: "https://artisanlanesa.co.za/vendor/subscription/error",
    notifyUrl: "https://example.supabase.co/functions/v1/payfast-itn",
  });

  const params = new URL(checkoutUrl).searchParams;
  assertEquals(params.get("amount"), "0.00");
  assertEquals(params.get("recurring_amount"), "349.00");
  assertEquals(params.get("subscription_type"), "1");
  assertEquals(params.get("frequency"), "3");
  assertEquals(params.get("cycles"), "0");
});
