import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { shouldAcceptTradeSafeDelivery } from "../_shared/order-fulfillment.ts";
import { sendInternalPushRequest } from "../_shared/push.ts";
import {
  acceptAllocationDelivery,
  getTradeSafeTransactionState,
} from "../_shared/tradesafe.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (request) => {
  try {
    const body = await request.json();
    const orderId = body.orderId as string;
    const adminPayout = body.adminPayout === true;
    const requestUserId =
      typeof body.userId === "string" && body.userId.trim().length > 0
        ? body.userId.trim()
        : null;

    let userId = requestUserId;
    let isAdmin = false;
    const authHeader = request.headers.get("Authorization");

    if (authHeader?.startsWith("Bearer ")) {
      try {
        const jwt = getBearerToken(request);
        const isServiceRoleRequest = jwt == supabaseServiceRoleKey;
        isAdmin = isServiceRoleRequest;

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

          if (!authError && user?.id != null) {
            userId = user.id;
          }
        }
      } catch (_) {
        // Fall back to the app-provided user ID when JWT verification is disabled.
      }
    }

    if (userId == null && !isAdmin) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const [{ data: profile }, { data: order }] = await Promise.all([
      userId != null
        ? admin.from("profiles").select("role").eq("id", userId).single()
        : Promise.resolve({ data: { role: "admin" } }),
      admin
        .from("orders")
        .select(
          "id, buyer_id, status, shipping_method, payment_provider, payment_state, tradesafe_transaction_id, tradesafe_allocation_id, received_at",
        )
        .eq("id", orderId)
        .single(),
    ]);

    if (order == null) {
      return jsonResponse({ error: "Order not found." }, { status: 404 });
    }

    isAdmin = isAdmin || profile?.role == "admin";
    const isBuyer = userId != null && order.buyer_id == userId;

    if (!isAdmin && !isBuyer) {
      return jsonResponse({ error: "You cannot release this escrow." }, {
        status: 403,
      });
    }

    if (adminPayout && !isAdmin) {
      return jsonResponse({ error: "Only an admin can trigger this payout." }, {
        status: 403,
      });
    }

    const releasableStatuses = adminPayout && isAdmin
      ? ["shipped", "delivered", "completed"]
      : ["paid", "shipped", "delivered"];
    if (!releasableStatuses.includes(order.status as string)) {
      return jsonResponse(
        {
          error: adminPayout
            ? "Only a shipped, delivered, or completed order can be paid out by an admin."
            : "This order cannot be released until payment is confirmed.",
        },
        { status: 400 },
      );
    }

    if (
      order.payment_provider !== "tradesafe" ||
      !order.tradesafe_transaction_id ||
      !shouldAcceptTradeSafeDelivery({
        allocationId: order.tradesafe_allocation_id as string | null,
        shippingMethod: order.shipping_method as string | null,
      })
    ) {
      return jsonResponse(
        { error: "This order does not have a releasable TradeSafe allocation." },
        { status: 400 },
      );
    }

    if (adminPayout) {
      const { count: openDisputeCount, error: disputeError } = await admin
        .from("disputes")
        .select("id", { count: "exact", head: true })
        .eq("order_id", orderId)
        .in("status", ["open", "investigating"]);
      if (disputeError) {
        throw new Error(disputeError.message);
      }
      if ((openDisputeCount ?? 0) > 0) {
        return jsonResponse(
          { error: "Resolve the open dispute before releasing this payout." },
          { status: 409 },
        );
      }
    }

    const transaction = await getTradeSafeTransactionState(
      order.tradesafe_transaction_id as string,
    );
    if (!transaction) {
      return jsonResponse(
        { error: "TradeSafe could not find this transaction." },
        { status: 404 },
      );
    }

    const allocation = transaction.allocations.find((candidate) =>
      candidate.id === order.tradesafe_allocation_id
    );
    if (!allocation) {
      return jsonResponse(
        { error: "TradeSafe could not find this order allocation." },
        { status: 404 },
      );
    }

    const payoutAlreadyReleased = transaction.state === "FUNDS_RELEASED";
    const payoutAlreadyInstructed = new Set([
      "DELIVERED",
      "DELIVERY_ACCEPTED",
      "DELIVERY_COMPLETED",
      "ACCEPTED",
    ]).has(allocation.state);

    let allocationState = allocation.state;
    let payoutStatus: "initiated" | "pending" | "released" =
      payoutAlreadyReleased ? "released" : "pending";

    if (!payoutAlreadyReleased && !payoutAlreadyInstructed) {
      if (!["FUNDS_RECEIVED", "INITIATED"].includes(transaction.state)) {
        return jsonResponse(
          {
            error:
              `TradeSafe has not confirmed releasable funds for this order (state: ${transaction.state}).`,
          },
          { status: 409 },
        );
      }

      const result = await acceptAllocationDelivery(
        order.tradesafe_allocation_id as string,
      );
      allocationState = result.allocationAcceptDelivery.state;
      payoutStatus = "initiated";
    }

    const completedAt = order.received_at ?? new Date().toISOString();
    const releasedAt = payoutAlreadyReleased ? new Date().toISOString() : null;
    const localPaymentState = payoutAlreadyReleased
      ? "FUNDS_RELEASED"
      : allocationState;

    await admin
      .from("orders")
      .update({
        status: "completed",
        payment_state: localPaymentState,
        received_at: completedAt,
      })
      .eq("id", orderId);

    await admin
      .from("escrow_transactions")
      .update({
        status: payoutAlreadyReleased ? "released" : "held",
        provider_state: localPaymentState,
        released_at: releasedAt,
      })
      .eq("order_id", orderId);

    await sendInternalPushRequest({
      supabaseUrl,
      serviceRoleKey: supabaseServiceRoleKey,
      body: {
        type: "order_update",
        orderId,
        event: "completed",
      },
    });

    return jsonResponse({
      ok: true,
      paymentState: localPaymentState,
      payoutStatus,
      releasedAt,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Unable to release funds.",
      },
      { status: 500 },
    );
  }
});
