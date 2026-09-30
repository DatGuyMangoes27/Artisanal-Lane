import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { shouldStartTradeSafeDelivery } from "../_shared/order-fulfillment.ts";
import { sendInternalPushRequest } from "../_shared/push.ts";
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
      .select(
        "id, shop_id, status, shipping_method, tradesafe_allocation_id, payment_state, shipped_at, tracking_number, tracking_url, bobgo_booking_state, bobgo_tracking_url",
      )
      .eq("id", orderId)
      .single();

    if (!order) {
      return jsonResponse({ error: "Order not found." }, { status: 404 });
    }

    if (!shop || order.shop_id !== shop.id) {
      return jsonResponse({ error: "You cannot update this order." }, {
        status: 403,
      });
    }

    if (["shipped", "delivered", "completed"].includes(order.status)) {
      return jsonResponse({
        ok: true,
        alreadyShipped: true,
        paymentState: order.payment_state,
        shippedAt: order.shipped_at,
      });
    }

    // A provider callback used to be able to downgrade a locally shipped
    // order back to `paid`. The existing shipped timestamp proves the seller's
    // action completed, so make retries repair the local status without
    // attempting TradeSafe's start-delivery mutation a second time.
    if (order.status === "paid" && order.shipped_at != null) {
      const repairUpdates: Record<string, string> = { status: "shipped" };
      if (trackingNumber != null) repairUpdates.tracking_number = trackingNumber;
      if (trackingUrl != null) repairUpdates.tracking_url = trackingUrl;

      const { error: repairError } = await admin
        .from("orders")
        .update(repairUpdates)
        .eq("id", orderId);

      if (repairError) {
        throw new Error(`Unable to restore shipped order: ${repairError.message}`);
      }

      return jsonResponse({
        ok: true,
        repaired: true,
        paymentState: order.payment_state,
        shippedAt: order.shipped_at,
      });
    }

    if (order.status !== "paid") {
      return jsonResponse(
        {
          error:
            "This order cannot be marked shipped until payment is confirmed.",
        },
        { status: 400 },
      );
    }

    // Bob Go orders use the courier booked automatically after payment. The
    // artisan cannot hand over a parcel that has no waybill yet, and the
    // tracking details come from the booking rather than manual entry.
    let effectiveTrackingNumber = trackingNumber ?? null;
    let effectiveTrackingUrl = trackingUrl ?? null;
    if (order.shipping_method === "bobgo_door_to_door") {
      if (order.bobgo_booking_state !== "booked") {
        return jsonResponse(
          {
            error:
              "The courier has not been booked for this order yet. Please try again shortly or contact support.",
          },
          { status: 409 },
        );
      }
      effectiveTrackingNumber = order.tracking_number as string | null;
      effectiveTrackingUrl = (order.bobgo_tracking_url ?? order.tracking_url) as string | null;
    }

    let allocationState = order.payment_state as string | null;
    if (
      order.tradesafe_allocation_id &&
      shouldStartTradeSafeDelivery(order.shipping_method as string | null)
    ) {
      const result = await startAllocationDelivery(
        order.tradesafe_allocation_id as string,
      );
      allocationState = result.allocationStartDelivery.state;
    }

    const shippedAt = new Date().toISOString();
    const orderUpdates: Record<string, string | null> = {
      status: "shipped",
      tracking_number: effectiveTrackingNumber,
      tracking_url: effectiveTrackingUrl,
      shipped_at: shippedAt,
    };
    if (allocationState != null) {
      orderUpdates.payment_state = allocationState;
    }

    const updates = [
      admin.from("orders").update(orderUpdates).eq("id", orderId),
    ];
    if (allocationState != null) {
      updates.push(
        admin
          .from("escrow_transactions")
          .update({
            provider_state: allocationState,
          })
          .eq("order_id", orderId),
      );
    }
    const updateResults = await Promise.all(updates);
    const updateError = updateResults.find((result) => result.error)?.error;
    if (updateError) {
      throw new Error(`Unable to save shipped order: ${updateError.message}`);
    }

    try {
      await sendInternalPushRequest({
        supabaseUrl,
        serviceRoleKey: supabaseServiceRoleKey,
        body: {
          type: "order_update",
          orderId,
          event: "shipped",
        },
      });
    } catch (pushError) {
      // Notification delivery must not turn a completed shipping update into
      // a 500 response that encourages the seller to submit it repeatedly.
      console.error("Unable to send shipped notification", pushError);
    }

    return jsonResponse({ ok: true, paymentState: allocationState, shippedAt });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Unable to update order.",
      },
      { status: 500 },
    );
  }
});
