import { createClient } from "npm:@supabase/supabase-js@2";

import {
  callPayFastValidate,
  getPayFastConfig,
  mapPayFastSubscriptionStatus,
  nextSubscriptionPeriodEnd,
  parsePayFastFormEncoded,
  verifyPayFastItnSignatureFromRaw,
} from "../_shared/payfast.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function textResponse(body: string, init: ResponseInit = {}) {
  return new Response(body, {
    ...init,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });
}

function toObject(params: URLSearchParams) {
  return Object.fromEntries(params.entries());
}

Deno.serve(async (request) => {
  const rawBody = await request.text();
  const params = parsePayFastFormEncoded(rawBody);
  const nowIso = new Date().toISOString();

  const config = (() => {
    try {
      return getPayFastConfig();
    } catch (error) {
      console.error("payfast-itn config error", error);
      return null;
    }
  })();

  const signatureCheck = config
    ? verifyPayFastItnSignatureFromRaw(rawBody, config.passphrase)
    : null;

  const vendorId = params.get("custom_str1")?.trim() || null;
  const checkoutReference = params.get("custom_str2")?.trim() || null;
  const paymentStatus = params.get("payment_status");
  const payfastPaymentId = params.get("pf_payment_id");
  const payfastToken = params.get("token");
  const payfastSubscriptionId = params.get("subscription_id");

  console.log("payfast-itn received", {
    vendorId,
    checkoutReference,
    paymentStatus,
    payfastPaymentId,
    payfastToken,
    signatureMatches: signatureCheck?.matches ?? false,
    providedSignature: signatureCheck?.providedSignature,
    expectedSignature: signatureCheck?.expectedSignature,
  });

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  if (vendorId != null) {
    await admin
      .from("vendor_subscriptions")
      .update({
        last_itn_at: nowIso,
        last_itn_payload: {
          body: toObject(params),
          signature_matches: signatureCheck?.matches ?? false,
          expected_signature: signatureCheck?.expectedSignature ?? null,
          received_at: nowIso,
        },
      })
      .eq("vendor_id", vendorId);
  }

  if (signatureCheck == null || !signatureCheck.matches) {
    if (vendorId != null) {
      await admin
        .from("vendor_subscriptions")
        .update({
          status_reason: "PayFast ITN signature did not match.",
        })
        .eq("vendor_id", vendorId);
    }
    console.warn("payfast-itn rejected signature", {
      vendorId,
      providedSignature: signatureCheck?.providedSignature,
      expectedSignature: signatureCheck?.expectedSignature,
      signingString: signatureCheck?.signingString,
    });
    return textResponse("OK");
  }

  if (config != null) {
    const validate = await callPayFastValidate(config.validateUrl, rawBody);
    console.log("payfast-itn validate response", validate);
  }

  if (vendorId == null) {
    return textResponse("OK");
  }

  const { data: existingSubscription } = await admin
    .from("vendor_subscriptions")
    .select(
      "vendor_id, status, current_period_start, current_period_end, payfast_payment_id, started_at, last_payment_at",
    )
    .eq("vendor_id", vendorId)
    .maybeSingle();

  const nextStatus = mapPayFastSubscriptionStatus(paymentStatus);
  const isDuplicatePayment = payfastPaymentId != null &&
    payfastPaymentId === existingSubscription?.payfast_payment_id;
  const nextPeriodEnd = nextStatus === "active" && !isDuplicatePayment
    ? nextSubscriptionPeriodEnd(
      existingSubscription?.current_period_end as string | null | undefined,
    )
    : existingSubscription?.current_period_end ?? null;

  await admin
    .from("vendor_subscriptions")
    .upsert({
      vendor_id: vendorId,
      plan_code: "artisan-monthly",
      amount: 349,
      currency: "ZAR",
      status: nextStatus,
      checkout_reference: checkoutReference,
      payfast_subscription_id: payfastSubscriptionId,
      payfast_token: payfastToken,
      payfast_payment_id: payfastPaymentId,
      payfast_email: params.get("email_address"),
      current_period_start: nextStatus === "active" && !isDuplicatePayment
        ? nowIso
        : existingSubscription?.current_period_start ?? null,
      current_period_end: nextPeriodEnd,
      started_at: existingSubscription?.started_at ??
        (nextStatus === "active" ? nowIso : null),
      last_payment_at: nextStatus === "active" && !isDuplicatePayment
        ? nowIso
        : existingSubscription?.last_payment_at ?? null,
      cancelled_at: nextStatus === "cancelled" ? nowIso : null,
      status_reason: nextStatus === "past_due"
        ? "PayFast marked the subscription payment as failed."
        : nextStatus === "cancelled"
        ? "PayFast marked the subscription as cancelled."
        : null,
      last_itn_at: nowIso,
      last_itn_payload: {
        body: toObject(params),
        signature_matches: true,
        expected_signature: signatureCheck.expectedSignature,
        received_at: nowIso,
      },
    });

  return textResponse("OK");
});
