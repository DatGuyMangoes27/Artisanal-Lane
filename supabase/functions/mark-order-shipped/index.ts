import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { startAllocationDelivery } from "../_shared/tradesafe.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (request) => {
  try {
    const body = await request.json();
    const orderId = body.orderId as string;
    const trackingNumber = body.trackingNumber as string | null | undefined;
    const trackingUrl = body.trackingUrl as string | null | undefined;
    const requestUserId =
      typeof body.userId === "string" && body.userId.trim().length > 0
        ? body.userId.trim()
        : null;

    let userId = requestUserId;
    const authHeader = request.headers.get("Authorization");

    if (authHeader?.startsWith("Bearer ")) {
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

        if (!authError && user?.id != null) {
          userId = user.id;
        }
      } catch (_) {
        // Fall back to the app-provided user ID when JWT verification is disabled.
      }
    }

    if (userId == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: shop } = await admin
      .from("shops")
      .select("id")
      .eq("vendor_id", userId)
      .maybeSingle();

    const { data: order } = await admin
      .from("orders")
      .select("id, shop_id, tradesafe_allocation_id")
      .eq("id", orderId)
      .single();

    if (!shop || order.shop_id !== shop.id) {
      return jsonResponse({ error: "You cannot update this order." }, { status: 403 });
    }

    let allocationState = "INITIATED";
    if (order.tradesafe_allocation_id) {
      const result = await startAllocationDelivery(order.tradesafe_allocation_id as string);
      allocationState = result.allocationStartDelivery.state;
    }

    const shippedAt = new Date().toISOString();

    await Promise.all([
      admin
        .from("orders")
        .update({
          status: "shipped",
          tracking_number: trackingNumber ?? null,
          tracking_url: trackingUrl ?? null,
          shipped_at: shippedAt,
          payment_state: allocationState,
        })
        .eq("id", orderId),
      admin
        .from("escrow_transactions")
        .update({
          provider_state: allocationState,
        })
        .eq("order_id", orderId),
    ]);

    return jsonResponse({ ok: true, paymentState: allocationState, shippedAt });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unable to update order." },
      { status: 500 },
    );
  }
});
