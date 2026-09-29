import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse } from "../_shared/http.ts";
import { sendInternalPushRequest } from "../_shared/push.ts";
import { createBobGoShipment } from "../_shared/bobgo.ts";
import {
  mapTradeSafeEscrowStatus,
  mapTradeSafeOrderStatus,
  shouldIgnoreTradeSafeCallback,
} from "../_shared/tradesafe-order-status.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const callbackSecret = Deno.env.get("TRADESAFE_CALLBACK_SECRET");
const tradeSafeProductionCallbackIps = new Set([
  "13.244.170.245",
  "13.244.43.204",
]);

function isAuthorizedCallback(request: Request, url: URL) {
  const suppliedSecret = url.searchParams.get("secret");
  if (callbackSecret && suppliedSecret === callbackSecret) {
    return true;
  }

  // TradeSafe documents these as its production callback IPs. Supabase's
  // Cloudflare gateway supplies cf-connecting-ip, so callers cannot choose it.
  const sourceIp = request.headers.get("cf-connecting-ip")?.trim();
  return sourceIp != null && tradeSafeProductionCallbackIps.has(sourceIp);
}

Deno.serve(async (request) => {
  try {
    const url = new URL(request.url);

    if (!isAuthorizedCallback(request, url)) {
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
        .select("id, buyer_id, shop_id, status, payment_state, shipping_method, bobgo_quote_id, bobgo_provider_slug, bobgo_service_level_code, bobgo_shipment_id, bobgo_booking_state")
        .eq("tradesafe_transaction_id", transactionId)
        .maybeSingle()
      : admin
        .from("orders")
        .select("id, buyer_id, shop_id, status, payment_state, shipping_method, bobgo_quote_id, bobgo_provider_slug, bobgo_service_level_code, bobgo_shipment_id, bobgo_booking_state")
        .eq("payment_reference", reference ?? "")
        .maybeSingle();

    const { data: order } = await orderLookup;

    if (!order) {
      return jsonResponse({ ok: true, ignored: true });
    }

    if (
      shouldIgnoreTradeSafeCallback({
        currentOrderStatus: order.status,
        currentPaymentState: order.payment_state as string | null,
        incomingTradeSafeState: state,
      })
    ) {
      return jsonResponse({ ok: true, ignored: true, reason: "stale_checkout_cancelled" });
    }

    const orderStatus = mapTradeSafeOrderStatus(state);
    const escrowStatus = mapTradeSafeEscrowStatus(state);
    const orderUpdate = {
      status: orderStatus,
      payment_state: state,
      payment_url: orderStatus === "paid" || orderStatus === "completed" ||
          orderStatus === "cancelled"
        ? null
        : undefined,
      tradesafe_transaction_id: transactionId,
      tradesafe_allocation_id: allocationId,
      paid_at: orderStatus === "paid" ? new Date().toISOString() : undefined,
    };

    await admin
      .from("orders")
      .update(orderUpdate)
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

    if (orderStatus === "paid" || orderStatus === "completed") {
      if (
        order.shipping_method === "bobgo_door_to_door" &&
        !order.bobgo_shipment_id &&
        order.bobgo_quote_id &&
        order.bobgo_provider_slug &&
        order.bobgo_service_level_code
      ) {
        const { data: claimedOrder } = await admin
          .from("orders")
          .update({ bobgo_booking_state: "booking", bobgo_booking_error: null })
          .eq("id", order.id)
          .in("bobgo_booking_state", ["not_requested", "failed"])
          .is("bobgo_shipment_id", null)
          .select("id")
          .maybeSingle();

        if (claimedOrder) {
          try {
            const { data: quote, error: quoteError } = await admin
              .from("bobgo_shipping_quotes")
              .select("request_snapshot")
              .eq("id", order.bobgo_quote_id)
              .single();
            if (quoteError || !quote) {
              throw new Error("The saved Bob Go shipment quote could not be loaded.");
            }

            const shipment = await createBobGoShipment({
              orderId: order.id,
              providerSlug: order.bobgo_provider_slug as string,
              serviceLevelCode: order.bobgo_service_level_code as string,
              rateRequestSnapshot: quote.request_snapshot,
            });
            await admin
              .from("orders")
              .update({
                bobgo_shipment_id: shipment.shipmentId,
                bobgo_booking_state: "booked",
                bobgo_status: shipment.status,
                bobgo_charged_amount: shipment.chargedAmount,
                tracking_number: shipment.trackingReference,
              })
              .eq("id", order.id);
          } catch (bookingError) {
            const message = bookingError instanceof Error
              ? bookingError.message
              : "Bob Go booking failed.";
            console.error(`[bobgo] order ${order.id} booking failed: ${message}`);
            await admin
              .from("orders")
              .update({
                bobgo_booking_state: "failed",
                bobgo_booking_error: message,
              })
              .eq("id", order.id);
          }
        }
      }

      await admin
        .from("chat_threads")
        .upsert(
          {
            shop_id: order.shop_id,
            buyer_id: order.buyer_id,
            kind: "buyer_vendor",
            last_message_preview: "New order placed",
            last_message_type: "text",
            last_message_at: new Date().toISOString(),
          },
          { onConflict: "shop_id,buyer_id", ignoreDuplicates: true },
        );

      const { data: cart } = await admin
        .from("carts")
        .select("id")
        .eq("user_id", order.buyer_id)
        .maybeSingle();

      if (cart?.id) {
        await admin.from("cart_items").delete().eq("cart_id", cart.id);
      }
    }

    if (orderStatus === "paid" || orderStatus === "cancelled") {
      await sendInternalPushRequest({
        supabaseUrl,
        serviceRoleKey: supabaseServiceRoleKey,
        body: {
          type: "order_update",
          orderId: order.id,
          event: orderStatus === "paid" ? "paid" : "cancelled",
        },
      });
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
