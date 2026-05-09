import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { cancelTradeSafeTransaction } from "../_shared/tradesafe.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const cleanupSecret = Deno.env.get("STALE_CHECKOUT_CLEANUP_SECRET");

type CancelledCheckout = {
  order_id: string;
  tradesafe_transaction_id: string | null;
  restored_item_count: number;
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

    const { data, error } = await admin.rpc("cancel_stale_checkout_orders", {
      stale_minutes: staleMinutes,
    });

    if (error) {
      throw new Error(error.message);
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
      upstreamCancelled,
      upstreamFailed,
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
