import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import {
  cancelTradeSafeTransaction,
  getTradeSafeTransactionState,
} from "../_shared/tradesafe.ts";
import {
  isTradeSafePaidState,
  mapTradeSafeEscrowStatus,
  mapTradeSafeOrderStatus,
} from "../_shared/tradesafe-order-status.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const cleanupSecret = Deno.env.get("STALE_CHECKOUT_CLEANUP_SECRET");

type CancelledCheckout = {
  order_id: string;
  tradesafe_transaction_id: string | null;
  restored_item_count: number;
};

type StaleCandidate = {
  id: string;
  buyer_id: string;
  shop_id: string;
  tradesafe_transaction_id: string | null;
};

function isAuthorized(request: Request) {
  if (cleanupSecret) {
    return request.headers.get("x-cleanup-secret") === cleanupSecret;
  }

  try {
    return getBearerToken(request) === supabaseServiceRoleKey;
  } catch (_) {
    return false;
  }
}

async function reconcilePaidTradeSafeTransactions(
  admin: ReturnType<typeof createClient>,
  staleMinutes: number,
) {
  const cutoff = new Date(Date.now() - staleMinutes * 60 * 1000).toISOString();
  const { data: candidates, error } = await admin
    .from("orders")
    .select("id, buyer_id, shop_id, tradesafe_transaction_id")
    .eq("status", "pending")
    .in("payment_state", ["checkout_created", "CREATED", "INITIATED"])
    .not("tradesafe_transaction_id", "is", null)
    .is("shipped_at", null)
    .is("received_at", null)
    .lte("created_at", cutoff);

  if (error) {
    throw new Error(error.message);
  }

  const reconciled: string[] = [];
  const failed: Array<{ orderId: string; error: string }> = [];

  for (const order of (candidates ?? []) as StaleCandidate[]) {
    try {
      const transaction = await getTradeSafeTransactionState(
        order.tradesafe_transaction_id!,
      );
      const transactionState = transaction?.state;

      if (!isTradeSafePaidState(transactionState)) {
        continue;
      }

      const allocation = transaction?.allocations?.[0];
      const orderStatus = mapTradeSafeOrderStatus(transactionState!);
      const escrowStatus = mapTradeSafeEscrowStatus(transactionState!);

      await admin
        .from("orders")
        .update({
          status: orderStatus,
          payment_state: transactionState,
          payment_url: null,
          tradesafe_allocation_id: allocation?.id,
          paid_at: orderStatus === "paid" ? new Date().toISOString() : undefined,
        })
        .eq("id", order.id);

      await admin
        .from("escrow_transactions")
        .update({
          status: escrowStatus,
          provider_state: transactionState,
          provider_allocation_id: allocation?.id,
        })
        .eq("order_id", order.id);

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

      reconciled.push(order.id);
    } catch (error) {
      failed.push({
        orderId: order.id,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  return { reconciled, failed };
}

Deno.serve(async (request) => {
  try {
    if (!isAuthorized(request)) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const url = new URL(request.url);
    const requestedMinutes = Number(url.searchParams.get("minutes"));
    const staleMinutes = Number.isFinite(requestedMinutes) &&
        requestedMinutes > 0
      ? Math.floor(requestedMinutes)
      : Number(Deno.env.get("STALE_CHECKOUT_MINUTES") ?? 30);

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const reconciliation = await reconcilePaidTradeSafeTransactions(
      admin,
      staleMinutes,
    );

    const { data, error } = await admin.rpc("cancel_stale_checkout_orders", {
      stale_minutes: staleMinutes,
    });

    if (error) {
      throw new Error(error.message);
    }

    const { data: expiredReservationQuantity, error: expiredReservationError } =
      await admin.rpc("expire_product_reservations");

    if (expiredReservationError) {
      throw new Error(expiredReservationError.message);
    }

    const cancelled = (data ?? []) as CancelledCheckout[];
    const upstreamResults = await Promise.allSettled(
      cancelled
        .filter((order) => order.tradesafe_transaction_id)
        .map((order) =>
          cancelTradeSafeTransaction(
            order.tradesafe_transaction_id!,
            "Checkout expired before payment was completed.",
          )
        ),
    );

    const upstreamCancelled = upstreamResults.filter(
      (result) => result.status === "fulfilled",
    ).length;
    const upstreamFailed = upstreamResults.length - upstreamCancelled;

    return jsonResponse({
      ok: true,
      staleMinutes,
      cancelledCount: cancelled.length,
      restoredItemCount: cancelled.reduce(
        (sum, order) => sum + order.restored_item_count,
        0,
      ),
      expiredReservationQuantity: expiredReservationQuantity ?? 0,
      upstreamCancelled,
      upstreamFailed,
      reconciledPaidCount: reconciliation.reconciled.length,
      reconciliationFailedCount: reconciliation.failed.length,
      reconciledPaidOrders: reconciliation.reconciled,
      reconciliationFailures: reconciliation.failed,
      orders: cancelled.map((order) => order.order_id),
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Could not clean stale checkouts.",
      },
      { status: 500 },
    );
  }
});
