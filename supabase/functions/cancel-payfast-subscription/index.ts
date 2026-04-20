import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { cancelPayFastSubscription } from "../_shared/payfast.ts";

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

    const { data: subscription } = await admin
      .from("vendor_subscriptions")
      .select(
        "vendor_id, status, payfast_token, payfast_subscription_id, current_period_end",
      )
      .eq("vendor_id", user.id)
      .maybeSingle();

    if (subscription == null) {
      return jsonResponse(
        { error: "No subscription found to cancel." },
        { status: 404 },
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

    const token = (subscription.payfast_token ?? subscription.payfast_subscription_id) as
      | string
      | null;

    const nowIso = new Date().toISOString();
    let payFastResult: { ok: boolean; status: number; body: unknown } | null = null;

    if (token != null && token.length > 0) {
      payFastResult = await cancelPayFastSubscription(token);
      console.log("cancel-payfast-subscription api response", payFastResult);
    } else {
      console.warn(
        "cancel-payfast-subscription: no token on record, marking local only",
        { vendorId: user.id },
      );
    }

    const apiFailed = payFastResult != null && !payFastResult.ok;
    if (apiFailed) {
      return jsonResponse(
        {
          error:
            "PayFast could not cancel the subscription right now. Please try again shortly.",
          details: payFastResult.body,
        },
        { status: 502 },
      );
    }

    await admin
      .from("vendor_subscriptions")
      .update({
        status: "cancelled",
        cancelled_at: nowIso,
        status_reason: "Cancelled by artisan from the app.",
      })
      .eq("vendor_id", user.id);

    return jsonResponse({
      status: "cancelled",
      cancelledAt: nowIso,
      currentPeriodEnd: subscription.current_period_end,
      payFastApiCalled: payFastResult != null,
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
