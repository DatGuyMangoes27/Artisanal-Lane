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

  const integrationType = params.get("custom_str1")?.trim() || null;
  const isStationeryPayment = integrationType === "stationery_request";
  const vendorId = isStationeryPayment
    ? params.get("custom_str3")?.trim() || null
    : params.get("custom_str1")?.trim() || null;
  const checkoutReference = isStationeryPayment
    ? params.get("custom_str4")?.trim() || null
    : params.get("custom_str2")?.trim() || null;
  const stationeryRequestId = isStationeryPayment
    ? params.get("custom_str2")?.trim() || null
    : null;
  const paymentStatus = params.get("payment_status");
  const payfastPaymentId = params.get("pf_payment_id");
  const payfastToken = params.get("token");
  const payfastSubscriptionId = params.get("subscription_id");

  console.log("payfast-itn received", {
    integrationType,
    vendorId,
    stationeryRequestId,
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
    if (isStationeryPayment) {
      await admin
        .from("stationery_requests")
        .update({
          last_itn_at: nowIso,
          last_itn_payload: {
            body: toObject(params),
            signature_matches: signatureCheck?.matches ?? false,
            expected_signature: signatureCheck?.expectedSignature ?? null,
            received_at: nowIso,
          },
        })
        .eq("id", stationeryRequestId ?? "")
        .eq("vendor_id", vendorId);
    } else {
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
  }

  if (signatureCheck == null || !signatureCheck.matches) {
    if (vendorId != null) {
      if (isStationeryPayment) {
        await admin
          .from("stationery_requests")
          .update({
            status_reason: "PayFast ITN signature did not match.",
          })
          .eq("id", stationeryRequestId ?? "")
          .eq("vendor_id", vendorId);
      } else {
        await admin
          .from("vendor_subscriptions")
          .update({
            status_reason: "PayFast ITN signature did not match.",
          })
          .eq("vendor_id", vendorId);
      }
    }
    console.warn("payfast-itn rejected signature", {
      vendorId,
      stationeryRequestId,
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

  if (isStationeryPayment) {
    if (stationeryRequestId == null) {
      return textResponse("OK");
    }

    const nextStatus = (() => {
      switch ((paymentStatus ?? "").toUpperCase()) {
        case "COMPLETE":
          return "paid";
        default:
          return "awaiting_payment";
      }
    })();

    const nextStatusReason = nextStatus === "paid"
      ? null
      : (paymentStatus ?? "").toUpperCase() === "CANCELLED"
      ? "The PayFast payment was cancelled."
      : "The PayFast payment did not complete.";

    await admin
      .from("stationery_requests")
      .update({
        status: nextStatus,
        payfast_payment_id: payfastPaymentId,
        payfast_email: params.get("email_address"),
        paid_at: nextStatus === "paid" ? nowIso : null,
        status_reason: nextStatusReason,
        checkout_reference: checkoutReference,
        last_itn_at: nowIso,
        last_itn_payload: {
          body: toObject(params),
          signature_matches: true,
          expected_signature: signatureCheck.expectedSignature,
          received_at: nowIso,
        },
      })
      .eq("id", stationeryRequestId)
      .eq("vendor_id", vendorId);

    return textResponse("OK");
  }

  const { data: existingSubscription } = await admin
    .from("vendor_subscriptions")
    .select(
      "vendor_id, status, current_period_start, current_period_end, payfast_payment_id, payfast_subscription_id, payfast_token, started_at, last_payment_at",
    )
    .eq("vendor_id", vendorId)
    .maybeSingle();

  let nextStatus = mapPayFastSubscriptionStatus(paymentStatus);
  const hasProvisionedSubscription = existingSubscription != null &&
    (
      existingSubscription.started_at != null ||
      existingSubscription.current_period_start != null ||
      existingSubscription.current_period_end != null ||
      existingSubscription.payfast_subscription_id != null ||
      existingSubscription.payfast_token != null
    );
  if (!hasProvisionedSubscription && nextStatus !== "active") {
    nextStatus = "inactive";
  }

  if (existingSubscription == null && nextStatus == "inactive") {
    return textResponse("OK");
  }

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
        : nextStatus === "inactive" && paymentStatus != null
        ? `PayFast returned ${paymentStatus.toUpperCase()} before the subscription became active.`
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
