import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse } from "../_shared/http.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const callbackSecret = Deno.env.get("TRADESAFE_CALLBACK_SECRET");

function mapOrderStatus(state: string) {
  switch (state) {
    case "FUNDS_RECEIVED":
      return "paid";
    case "CANCELLED":
    case "FAILED":
    case "EXPIRED":
      return "cancelled";
    default:
      return "pending";
  }
}

function mapEscrowStatus(state: string) {
  switch (state) {
    case "FUNDS_RECEIVED":
      return "held";
    case "CANCELLED":
    case "FAILED":
    case "EXPIRED":
      return "cancelled";
    default:
      return "pending";
  }
}

Deno.serve(async (request) => {
  try {
    const url = new URL(request.url);

    if (callbackSecret && url.searchParams.get("secret") !== callbackSecret) {
      return jsonResponse({ error: "Unauthorized callback." }, { status: 401 });
    }

    const payload = await request.json();
    const data = (payload.data ?? payload) as Record<string, unknown>;

    const transactionId = (data.transactionId ?? data.id) as string | undefined;
    const reference = data.reference as string | undefined;
    const state = (data.state ?? data.status ?? "UNKNOWN") as string;
    const allocationId = Array.isArray(data.allocations)
      ? (data.allocations[0] as Record<string, unknown> | undefined)?.id as
          | string
          | undefined
      : undefined;

    if (!transactionId && !reference) {
      return jsonResponse(
        { error: "Missing transaction reference." },
        { status: 400 },
      );
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const orderLookup = transactionId
      ? admin
          .from("orders")
          .select("id, buyer_id")
          .eq("tradesafe_transaction_id", transactionId)
          .maybeSingle()
      : admin
          .from("orders")
          .select("id, buyer_id")
          .eq("payment_reference", reference ?? "")
          .maybeSingle();

    const { data: order } = await orderLookup;

    if (!order) {
      return jsonResponse({ ok: true, ignored: true });
    }

    const orderStatus = mapOrderStatus(state);
    const escrowStatus = mapEscrowStatus(state);

    await admin
      .from("orders")
      .update({
        status: orderStatus,
        payment_state: state,
        payment_url:
          orderStatus === "paid" || orderStatus === "cancelled" ? null : undefined,
        tradesafe_transaction_id: transactionId,
        tradesafe_allocation_id: allocationId,
        paid_at: orderStatus === "paid" ? new Date().toISOString() : null,
      })
      .eq("id", order.id);

    await admin
      .from("escrow_transactions")
      .update({
        status: escrowStatus,
        provider_transaction_id: transactionId,
        provider_allocation_id: allocationId,
        provider_state: state,
      })
      .eq("order_id", order.id);

    if (orderStatus === "paid") {
      const { data: cart } = await admin
        .from("carts")
        .select("id")
        .eq("user_id", order.buyer_id)
        .maybeSingle();

      if (cart?.id) {
        await admin.from("cart_items").delete().eq("cart_id", cart.id);
      }
    }

    return jsonResponse({ ok: true });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Callback failed.",
      },
      { status: 500 },
    );
  }
});
