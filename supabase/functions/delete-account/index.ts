import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { cancelPayFastSubscription } from "../_shared/payfast.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const activeVendorOrderStatuses = [
  "pending",
  "paid",
  "shipped",
  "delivered",
  "disputed",
];

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

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id, role")
      .eq("id", user.id)
      .single();

    if (profileError != null || profile == null) {
      return jsonResponse(
        { error: "Could not load your account details." },
        { status: 404 },
      );
    }

    if (profile.role === "admin") {
      return jsonResponse(
        { error: "Admin accounts cannot be deleted from the app." },
        { status: 403 },
      );
    }

    if (profile.role === "vendor") {
      const { data: shop } = await admin
        .from("shops")
        .select("id")
        .eq("vendor_id", user.id)
        .maybeSingle();

      if (shop?.id != null) {
        const { count: activeOrderCount, error: orderCountError } = await admin
          .from("orders")
          .select("id", { count: "exact", head: true })
          .eq("shop_id", shop.id)
          .in("status", activeVendorOrderStatuses);

        if (orderCountError != null) {
          return jsonResponse(
            { error: "Could not verify your active orders." },
            { status: 500 },
          );
        }

        if ((activeOrderCount ?? 0) > 0) {
          return jsonResponse(
            {
              error:
                "You still have active orders. Please complete or resolve them before deleting your vendor account.",
            },
            { status: 409 },
          );
        }
      }

      const { data: subscription } = await admin
        .from("vendor_subscriptions")
        .select("status, payfast_token, payfast_subscription_id")
        .eq("vendor_id", user.id)
        .maybeSingle();

      if (subscription != null && subscription.status !== "cancelled") {
        const token = (subscription.payfast_token ??
          subscription.payfast_subscription_id) as string | null;

        if (token != null && token.length > 0) {
          const cancelResult = await cancelPayFastSubscription(token);
          if (!cancelResult.ok) {
            return jsonResponse(
              {
                error:
                  "Your subscription could not be cancelled right now. Please try again shortly.",
              },
              { status: 502 },
            );
          }
        }

        await admin
          .from("vendor_subscriptions")
          .update({
            status: "cancelled",
            cancelled_at: new Date().toISOString(),
            status_reason: "Cancelled during account deletion.",
          })
          .eq("vendor_id", user.id);
      }
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError != null) {
      return jsonResponse(
        {
          error: deleteError.message || "Could not delete your account.",
        },
        { status: 500 },
      );
    }

    return jsonResponse({
      success: true,
      role: profile.role,
      message: "Your account has been deleted.",
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Could not delete your account.",
      },
      { status: 500 },
    );
  }
});
