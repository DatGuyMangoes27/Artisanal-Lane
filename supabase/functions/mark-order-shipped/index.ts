import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { startAllocationDelivery } from "../_shared/tradesafe.ts";

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
    const trackingNumber = body.trackingNumber as string | null | undefined;

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: shop } = await admin
      .from("shops")
      .select("id")
      .eq("vendor_id", user.id)
      .maybeSingle();

    const { data: order } = await admin
      .from("orders")
      .select("id, shop_id, tradesafe_allocation_id")
      .eq("id", orderId)
      .single();

    if (!shop || order.shop_id !== shop.id) {
      return jsonResponse({ error: "You cannot update this order." }, { status: 403 });
    }

    if (order.tradesafe_allocation_id) {
      await startAllocationDelivery(order.tradesafe_allocation_id as string);
    }

    await admin
      .from("orders")
      .update({
        status: "shipped",
        tracking_number: trackingNumber ?? null,
      })
      .eq("id", orderId);

    return jsonResponse({ ok: true });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unable to update order." },
      { status: 500 },
    );
  }
});
