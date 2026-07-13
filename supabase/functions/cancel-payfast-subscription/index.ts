import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { cancelPayFastSubscription } from "../_shared/payfast.ts";
import { getPayFastCancellationToken } from "../_shared/subscription-cancellation.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

    const { data: subscription, error: subscriptionError } = await admin
      .from("vendor_subscriptions")
      .select(
        "vendor_id, status, payfast_token, payfast_subscription_id, current_period_end",
      )
      .eq("vendor_id", user.id)
      .maybeSingle();

    if (subscriptionError != null) {
      return jsonResponse(
        { error: "Could not load your subscription right now." },
        { status: 500 },
      );
    }

    if (subscription == null) {
      return jsonResponse(
        { error: "No subscription found to cancel." },
        { status: 404 },
      );
    }

    const token = getPayFastCancellationToken(subscription);

    if (token == null) {
      console.error("cancel-payfast-subscription: PayFast token is missing", {
        vendorId: user.id,
      });
      return jsonResponse(
        {
          error:
            "We could not verify your PayFast subscription token. Your subscription has not been cancelled; please contact support.",
        },
        { status: 409 },
      );
    }

    if (subscription.status === "cancelled") {
      return jsonResponse(
        {
          status: "cancelled",
          message: "Subscription is already cancelled.",
        },
      );
    }

    const nowIso = new Date().toISOString();
    const payFastResult = await cancelPayFastSubscription(token);
    console.log("cancel-payfast-subscription api response", {
      ok: payFastResult.ok,
      status: payFastResult.status,
    });

    if (!payFastResult.ok) {
      return jsonResponse(
        {
          error:
            "PayFast could not cancel the subscription right now. Please try again shortly.",
        },
        { status: 502 },
      );
    }

    const { error: updateError } = await admin
      .from("vendor_subscriptions")
      .update({
        status: "cancelled",
        cancelled_at: nowIso,
        status_reason: "PayFast cancellation confirmed after artisan request.",
      })
      .eq("vendor_id", user.id);

    if (updateError != null) {
      console.error("cancel-payfast-subscription: local update failed", {
        vendorId: user.id,
        message: updateError.message,
      });
      return jsonResponse(
        {
          error:
            "PayFast cancelled the subscription, but Artisan Lane could not save the update. Please contact support.",
        },
        { status: 500 },
      );
    }

    return jsonResponse({
      status: "cancelled",
      cancelledAt: nowIso,
      currentPeriodEnd: subscription.current_period_end,
      payFastApiCalled: true,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Could not cancel subscription.",
      },
      { status: 500 },
    );
  }
});
