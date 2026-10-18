import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { sendInternalPushRequest } from "../_shared/push.ts";
import { cancelTradeSafeTransaction } from "../_shared/tradesafe.ts";
import { cancelBobGoShipment } from "../_shared/bobgo.ts";
import { shouldCancelBobGoShipment } from "../_shared/bobgo-tracking.mjs";

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

      if (profile?.role != "admin") {
        return jsonResponse({ error: "Only admins can issue refunds." }, {
          status: 403,
        });
      }
    }

    if (!isServiceRoleRequest && userId == null) {
      return jsonResponse({ error: "Only admins can issue refunds." }, {
        status: 403,
      });
    }

    const body = await request.json();
    const orderId = body.orderId as string;
    const reason = (body.reason as string | null) ??
      "Refund approved by admin.";

    const { data: order } = await admin
      .from("orders")
      .select(
        "id, tradesafe_transaction_id, shipping_method",
      )
      .eq("id", orderId)
      .single();

    if (order == null) {
      return jsonResponse({ error: "Order not found." }, { status: 404 });
    }

    if (order.tradesafe_transaction_id) {
      await cancelTradeSafeTransaction(
        order.tradesafe_transaction_id as string,
        reason,
      );
    }

    // The buyer's money is refunded first (above). The order is then marked
    // cancelled, which stops any new courier booking (bookings only claim
    // 'paid' orders, and one already in flight cancels itself when it sees the
    // order cancelled - see _shared/bobgo-booking.ts).
    await admin
      .from("orders")
      .update({ status: "cancelled", payment_state: "refunded" })
      .eq("id", orderId);

    // Then a booked courier is cancelled best-effort, using a fresh read so a
    // booking that completed during the refund is included. If Bob Go refuses
    // (e.g. already collected) the refund still stands and the failure is
    // recorded for an admin to follow up.
    let bobGoCancelError: string | null = null;
    if (order.shipping_method === "bobgo_door_to_door") {
      // Never booked: close it so nothing books it later.
      await admin
        .from("orders")
        .update({ bobgo_booking_state: "cancelled", bobgo_cancelled_at: new Date().toISOString() })
        .eq("id", orderId)
        .in("bobgo_booking_state", ["not_requested", "failed"])
        .is("bobgo_shipment_id", null);

      const { data: fresh } = await admin
        .from("orders")
        .select(
          "id, shipping_method, tracking_number, bobgo_shipment_id, bobgo_booking_state, bobgo_status, bobgo_cancelled_at, bobgo_delivered_at",
        )
        .eq("id", orderId)
        .single();

      const bobGoUpdate: Record<string, unknown> = {};
      if (fresh?.bobgo_booking_state === "booking") {
        bobGoCancelError =
          "A courier booking was in progress during the refund; it cancels itself when it completes. Check Bob Go if bobgo_booking_state stays 'booking'.";
        bobGoUpdate.bobgo_cancel_error = bobGoCancelError;
      } else if (shouldCancelBobGoShipment(fresh)) {
        try {
          await cancelBobGoShipment(fresh!.tracking_number as string);
          bobGoUpdate.bobgo_booking_state = "cancelled";
          bobGoUpdate.bobgo_status = "cancelled";
          bobGoUpdate.bobgo_cancelled_at = new Date().toISOString();
          bobGoUpdate.bobgo_cancel_error = null;
        } catch (cancelError) {
          bobGoCancelError = cancelError instanceof Error
            ? cancelError.message
            : "Bob Go cancellation failed.";
          console.error(`[bobgo] order ${orderId} shipment cancel failed: ${bobGoCancelError}`);
          bobGoUpdate.bobgo_cancel_error = bobGoCancelError.slice(0, 500);
        }
      }
      if (Object.keys(bobGoUpdate).length > 0) {
        await admin.from("orders").update(bobGoUpdate).eq("id", orderId);
      }
    }

    await admin
      .from("escrow_transactions")
      .update({
        status: "refunded",
        provider_state: "REFUNDED",
        released_at: new Date().toISOString(),
      })
      .eq("order_id", orderId);

    try {
      await sendInternalPushRequest({
        supabaseUrl,
        serviceRoleKey: supabaseServiceRoleKey,
        body: {
          type: "order_update",
          orderId,
          event: "cancelled",
        },
      });
    } catch (pushError) {
      // The refund already went through; a notification failure must not turn
      // it into an error response (matches the live behaviour).
      console.error("Unable to send refund notification", pushError);
    }

    return jsonResponse({
      ok: true,
      ...(bobGoCancelError ? { bobGoCancelError } : {}),
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Refund failed." },
      { status: 500 },
    );
  }
});
