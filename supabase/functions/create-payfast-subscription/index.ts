import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { buildPayFastSubscriptionCheckoutUrl } from "../_shared/payfast.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const artisanSubscriptionAmount = 349;
const artisanSubscriptionPlanCode = "artisan-monthly";
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
          .select("status, current_period_end")
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

    const checkoutReference = crypto.randomUUID();
    const paymentReference = `artisan-subscription-${user.id}`;
    const displayName = firstNonEmptyString(profile?.display_name, shop.name) ??
      "Artisan Lane Artisan";
    const email = firstNonEmptyString(profile?.email) ??
      `${user.id}@artisanlane.local`;
    const notifyUrl = `${supabaseUrl}/functions/v1/payfast-itn`;

    const checkoutUrl = buildPayFastSubscriptionCheckoutUrl({
      amount: 0,
      recurringAmount: artisanSubscriptionAmount,
      itemName: "Artisan Lane Subscription",
      itemDescription: "Artisan subscription with first month free",
      reference: paymentReference,
      vendorId: user.id,
      checkoutReference,
      email,
      displayName,
      returnUrl: subscriptionReturnUrl,
      cancelUrl: subscriptionCancelUrl,
      notifyUrl,
    });

    return jsonResponse({
      checkoutUrl,
      checkoutReference,
      amount: 0,
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
