import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { disputeAllocationDelivery } from "../_shared/tradesafe.ts";

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

    if (authError || !user) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const orderId = body.orderId as string;
    const reason = body.reason as string;

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: order } = await admin
      .from("orders")
      .select("id, buyer_id, tradesafe_allocation_id")
      .eq("id", orderId)
      .single();

    if (order.buyer_id != user.id) {
      return jsonResponse({ error: "You cannot dispute this order." }, { status: 403 });
    }

    if (order.tradesafe_allocation_id) {
      await disputeAllocationDelivery(order.tradesafe_allocation_id as string);
    }

    await admin.from("disputes").insert({
      order_id: orderId,
      raised_by: user.id,
      reason,
      status: "open",
    });

    await admin
      .from("orders")
      .update({
        status: "disputed",
        payment_state: "disputed",
      })
      .eq("id", orderId);

    return jsonResponse({ ok: true });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Unable to open dispute.",
      },
      { status: 500 },
    );
  }
});
