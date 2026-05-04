import { assertEquals } from "jsr:@std/assert";

import {
  buildPayFastSignature,
  buildPayFastSubscriptionCheckoutUrl,
  verifyPayFastItnSignatureFromRaw,
} from "./payfast.ts";

Deno.test("subscription checkout supports free-trial initial amount with recurring amount", () => {
  Deno.env.set("PAYFAST_MERCHANT_ID", "10000100");
  Deno.env.set("PAYFAST_MERCHANT_KEY", "46f0cd694581a");
  Deno.env.set("PAYFAST_PASSPHRASE", "test-passphrase");
  Deno.env.set("PAYFAST_SANDBOX", "true");

  const checkoutUrl = buildPayFastSubscriptionCheckoutUrl({
    amount: 0,
    recurringAmount: 349,
    itemName: "Artisan Lane Subscription",
    itemDescription: "Artisan subscription with first two months free",
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
  assertEquals(params.get("billing_date") != null, true);
});

Deno.test("itn signature verification ignores blank fields in the posted body", () => {
  const passphrase = "test-passphrase";
  const nonBlankEntries: Array<[string, string]> = [
    ["m_payment_id", "artisan-subscription-vendor-1"],
    ["pf_payment_id", "298756509"],
    ["payment_status", "COMPLETE"],
    ["item_name", "Artisan Lane Subscription"],
    ["item_description", "Artisan subscription with first two months free"],
    ["amount_gross", "0.00"],
    ["amount_fee", "0.00"],
    ["amount_net", "0.00"],
    ["custom_str1", "vendor-1"],
    ["custom_str2", "checkout-1"],
    ["name_first", "Nicky"],
    ["name_last", "Lane"],
    ["email_address", "nicky@artisanlanesa.com"],
    ["merchant_id", "34629527"],
    ["token", "2ca69e37-66b8-40e9-bf75-d4bf0279c8d9"],
    ["billing_date", "2026-06-04"],
  ];
  const signature = buildPayFastSignature(nonBlankEntries, passphrase);

  const rawParams = new URLSearchParams();
  rawParams.append("m_payment_id", "artisan-subscription-vendor-1");
  rawParams.append("pf_payment_id", "298756509");
  rawParams.append("payment_status", "COMPLETE");
  rawParams.append("item_name", "Artisan Lane Subscription");
  rawParams.append("item_description", "Artisan subscription with first two months free");
  rawParams.append("amount_gross", "0.00");
  rawParams.append("amount_fee", "0.00");
  rawParams.append("amount_net", "0.00");
  rawParams.append("custom_str1", "vendor-1");
  rawParams.append("custom_str2", "checkout-1");
  rawParams.append("custom_str3", "");
  rawParams.append("custom_str4", "");
  rawParams.append("custom_str5", "");
  rawParams.append("custom_int1", "");
  rawParams.append("custom_int2", "");
  rawParams.append("custom_int3", "");
  rawParams.append("custom_int4", "");
  rawParams.append("custom_int5", "");
  rawParams.append("name_first", "Nicky");
  rawParams.append("name_last", "Lane");
  rawParams.append("email_address", "nicky@artisanlanesa.com");
  rawParams.append("merchant_id", "34629527");
  rawParams.append("token", "2ca69e37-66b8-40e9-bf75-d4bf0279c8d9");
  rawParams.append("billing_date", "2026-06-04");
  rawParams.append("signature", signature);

  const verification = verifyPayFastItnSignatureFromRaw(
    rawParams.toString(),
    passphrase,
  );

  assertEquals(verification.matches, true);
});
