// The buyer's multi-shop checkout: funds each shop's order from their basket
// payment once it has arrived, and reports progress. The app and website call
// this while the TradeSafe payment page is open and when the buyer returns.

import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse, optionsResponse } from "../_shared/http.ts";
import { fundCheckoutGroup } from "../_shared/checkout-groups.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    let jwt: string;
    try {
      jwt = getBearerToken(request);
    } catch (_) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }
    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await client.auth.getUser();
    if (authError || !user) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json().catch(() => ({}));
    const groupId = typeof body.checkoutGroupId === "string" ? body.checkoutGroupId.trim() : "";
    if (!groupId) {
      return jsonResponse({ error: "Missing checkout." }, { status: 400 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: group } = await admin
      .from("checkout_groups")
      .select("id, buyer_id, deposit_url, deposit_expires_at")
      .eq("id", groupId)
      .maybeSingle();
    if (!group || group.buyer_id !== user.id) {
      return jsonResponse({ error: "Checkout not found." }, { status: 404 });
    }

    const result = await fundCheckoutGroup(admin, groupId, {
      supabaseUrl,
      serviceRoleKey: supabaseServiceRoleKey,
    });

    return jsonResponse({
      checkoutGroupId: result.groupId,
      status: result.status,
      orderIds: result.orderIds,
      paidOrderIds: result.paidOrderIds,
      checkoutUrl: result.status === "awaiting_payment" ? group.deposit_url : null,
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Could not check this payment." },
      { status: 500 },
    );
  }
});
