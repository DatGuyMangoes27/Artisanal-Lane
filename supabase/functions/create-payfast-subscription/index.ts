import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { buildPayFastSubscriptionCheckoutUrl } from "../_shared/payfast.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const artisanSubscriptionAmount = 349;
const artisanSubscriptionPlanCode = "artisan-monthly";
// Founders offer: the first 100 shops pay R199/month, price locked for a year.
const foundersPlanCode = "founders-199";
const foundersAmount = 199;
const foundersLimit = 100;
const signUpFreeMonths = 1;
const subscriptionReturnUrl =
  "https://artisanlanesa.co.za/vendor/subscription/success";
const subscriptionCancelUrl =
  "https://artisanlanesa.co.za/vendor/subscription/error";

function firstNonEmptyString(...values: Array<unknown>) {
  for (const value of values) {
    if (typeof value !== "string") continue;
    const trimmed = value.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
  }
  return null;
}

Deno.serve(async (request) => {
  try {
    const jwt = getBearerToken(request);
    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const {
      data: { user },
      error: authError,
    } = await client.auth.getUser();

    if (authError != null || user?.id == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const [{ data: profile }, { data: shop }, { data: existingSubscription }] =
      await Promise.all([
        admin
          .from("profiles")
          .select("id, role, display_name, email")
          .eq("id", user.id)
          .single(),
        admin
          .from("shops")
          .select("id, name")
          .eq("vendor_id", user.id)
          .maybeSingle(),
        admin
          .from("vendor_subscriptions")
          .select("status, current_period_end, plan_code")
          .eq("vendor_id", user.id)
          .maybeSingle(),
      ]);

    if (profile?.role !== "vendor") {
      return jsonResponse(
        { error: "Only approved artisans can start a subscription." },
        { status: 403 },
      );
    }

    if (shop == null) {
      return jsonResponse(
        { error: "Finish your artisan onboarding before starting billing." },
        { status: 400 },
      );
    }

    const currentPeriodEnd = existingSubscription?.current_period_end as
      | string
      | null
      | undefined;
    const hasActiveSubscription = existingSubscription?.status === "active" &&
      (currentPeriodEnd == null || new Date(currentPeriodEnd) > new Date());

    if (hasActiveSubscription) {
      return jsonResponse(
        { error: "Your artisan subscription is already active." },
        { status: 400 },
      );
    }

    // Returning founders keep their plan; otherwise founders places are
    // first come, first served among shops that actually started billing.
    let isFounder = existingSubscription?.plan_code === foundersPlanCode;
    if (!isFounder) {
      const { count, error: foundersError } = await admin
        .from("vendor_subscriptions")
        .select("vendor_id", { count: "exact", head: true })
        .eq("plan_code", foundersPlanCode)
        .not("started_at", "is", null);
      if (foundersError != null) {
        return jsonResponse(
          { error: "Could not prepare your subscription. Please try again." },
          { status: 500 },
        );
      }
      isFounder = (count ?? 0) < foundersLimit;
    }
    const planCode = isFounder ? foundersPlanCode : artisanSubscriptionPlanCode;
    const planAmount = isFounder ? foundersAmount : artisanSubscriptionAmount;

    const checkoutReference = crypto.randomUUID();
    const paymentReference = `artisan-subscription-${user.id}`;
    const displayName = firstNonEmptyString(profile?.display_name, shop.name) ??
      "Artisan Lane Artisan";
    const email = firstNonEmptyString(profile?.email) ??
      `${user.id}@artisanlane.local`;
    const notifyUrl = `${supabaseUrl}/functions/v1/payfast-itn`;

    const checkoutUrl = buildPayFastSubscriptionCheckoutUrl({
      amount: 0,
      recurringAmount: planAmount,
      itemName: isFounder
        ? "Artisan Lane Founders Subscription"
        : "Artisan Lane Subscription",
      itemDescription: isFounder
        ? "First month free, then R199/month locked for 12 months"
        : "First month free, then R349/month",
      freeMonths: signUpFreeMonths,
      reference: paymentReference,
      vendorId: user.id,
      checkoutReference,
      email,
      displayName,
      returnUrl: subscriptionReturnUrl,
      cancelUrl: subscriptionCancelUrl,
      notifyUrl,
    });

    const checkoutRecord = existingSubscription == null
      ? admin.from("vendor_subscriptions").insert({
        vendor_id: user.id,
        plan_code: planCode,
        amount: planAmount,
        currency: "ZAR",
        status: "inactive",
        checkout_reference: checkoutReference,
        status_reason: "Awaiting PayFast confirmation.",
      })
      : admin.from("vendor_subscriptions").update({
        plan_code: planCode,
        amount: planAmount,
        checkout_reference: checkoutReference,
        status: "inactive",
        status_reason: "Awaiting PayFast confirmation.",
        cancelled_at: null,
      }).eq("vendor_id", user.id);

    const { error: checkoutRecordError } = await checkoutRecord;
    if (checkoutRecordError != null) {
      console.error("create-payfast-subscription checkout record failed", {
        vendorId: user.id,
        message: checkoutRecordError.message,
      });
      return jsonResponse(
        { error: "Could not prepare your subscription. Please try again." },
        { status: 500 },
      );
    }

    return jsonResponse({
      checkoutUrl,
      checkoutReference,
      amount: 0,
      recurringAmount: planAmount,
      founders: isFounder,
      status: "inactive",
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Could not create subscription checkout.",
      },
      { status: 500 },
    );
  }
});
