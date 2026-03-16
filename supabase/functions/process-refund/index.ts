import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { cancelTradeSafeTransaction } from "../_shared/tradesafe.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (request) => {
  try {
    const jwt = getBearerToken(request);
    const isServiceRoleRequest = jwt == supabaseServiceRoleKey;
    let userId: string | null = null;

    if (!isServiceRoleRequest) {
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

      if (authError || !user) {
        return jsonResponse({ error: "Unauthorized" }, { status: 401 });
      }

      userId = user.id;
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    if (!isServiceRoleRequest && userId == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    if (!isServiceRoleRequest) {
      const { data: profile } = await admin
        .from("profiles")
        .select("role")
        .eq("id", userId!)
        .single();

      if (profile.role != "admin") {
        return jsonResponse({ error: "Only admins can issue refunds." }, { status: 403 });
      }
    }

    if (!isServiceRoleRequest && userId == null) {
      return jsonResponse({ error: "Only admins can issue refunds." }, { status: 403 });
    }

    const body = await request.json();
    const orderId = body.orderId as string;
    const reason =
      (body.reason as string | null) ?? "Refund approved by admin.";

    const { data: order } = await admin
      .from("orders")
      .select("id, tradesafe_transaction_id")
      .eq("id", orderId)
      .single();

    if (order.tradesafe_transaction_id) {
      await cancelTradeSafeTransaction(order.tradesafe_transaction_id as string, reason);
    }

    await admin
      .from("orders")
      .update({
        status: "cancelled",
        payment_state: "refunded",
      })
      .eq("id", orderId);

    await admin
      .from("escrow_transactions")
      .update({
        status: "refunded",
        provider_state: "REFUNDED",
        released_at: new Date().toISOString(),
      })
      .eq("order_id", orderId);

    return jsonResponse({ ok: true });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Refund failed." },
      { status: 500 },
    );
  }
});
