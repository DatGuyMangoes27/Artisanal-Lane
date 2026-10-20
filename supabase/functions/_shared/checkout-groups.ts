// Multi-shop checkout funding (see migration 20261020120000).
//
// The buyer pays once into their own TradeSafe wallet; each shop's order has
// its own TradeSafe transaction, which is funded here from that wallet.
//
// A basket is only ever funded, expired or cancelled here, while holding the
// group's claim, so these never race each other. Stale cleanup skips basket
// orders. Each order records group_funded_at the moment its transaction is
// paid from the wallet, so no shop is ever paid twice.
//
// Called while the buyer pays (checkout-group-status), every five minutes by
// cleanup-stale-checkouts, and by create-checkout before a buyer's new basket
// replaces an older unpaid one.

import type { SupabaseClient as TypedSupabaseClient } from "npm:@supabase/supabase-js@2";

import { bookBobGoShipmentForOrder } from "./bobgo-booking.ts";
import { sendInternalPushRequest } from "./push.ts";
import {
  cancelTradeSafeTransaction,
  fundTradeSafeTransactionFromWallet,
  getTradeSafeTokenBalance,
  getTradeSafeTransactionState,
} from "./tradesafe.ts";
import { isTradeSafePaidState } from "./tradesafe-order-status.ts";

// Edge functions create their clients without generated database types.
// deno-lint-ignore no-explicit-any
type SupabaseClient = TypedSupabaseClient<any, any, any>;

type PushConfig = { supabaseUrl: string; serviceRoleKey: string };

// A funding run makes a few TradeSafe calls per shop; a claim older than this
// was abandoned (the function timed out) and may be taken over.
const FUNDING_CLAIM_MS = 5 * 60 * 1000;
// A basket still being created after this long failed part-way.
const BUILDING_TIMEOUT_MS = 10 * 60 * 1000;
// Unpaid baskets expire this long after their payment link does, giving a
// payment made at the last minute time to arrive.
const PAYMENT_GRACE_MS = 15 * 60 * 1000;

type GroupOrder = {
  id: string;
  buyer_id: string;
  shop_id: string;
  status: string;
  payment_state: string | null;
  shipping_method: string | null;
  tradesafe_transaction_id: string | null;
  tradesafe_buyer_deposit: number | null;
  group_funded_at: string | null;
  bobgo_quote_id: string | null;
  bobgo_provider_slug: string | null;
  bobgo_service_level_code: string | null;
  bobgo_shipment_id: string | null;
  bobgo_booking_state: string | null;
};

type Group = {
  id: string;
  buyer_id: string;
  status: string;
  buyer_token_id: string;
  deposit_expires_at: string | null;
  created_at: string;
};

export type CheckoutGroupResult = {
  groupId: string;
  status: string;
  orderIds: string[];
  paidOrderIds: string[];
};

const now = () => new Date().toISOString();

/** Same effects as tradesafe-callback when an order becomes paid. */
export async function applyPaidOrderEffects(
  admin: SupabaseClient,
  order: GroupOrder,
  state: string,
  push: PushConfig,
) {
  const { data: updated } = await admin
    .from("orders")
    .update({ status: "paid", payment_state: state, payment_url: null, paid_at: now() })
    .eq("id", order.id)
    .eq("status", "pending")
    .select("id");
  // TradeSafe's own callback got there first and did all of this already.
  if (!updated || updated.length === 0) return;

  await admin
    .from("escrow_transactions")
    .update({ status: "held", provider_state: state })
    .eq("order_id", order.id);

  if (order.shipping_method === "bobgo_door_to_door") {
    try {
      await bookBobGoShipmentForOrder(admin, order);
    } catch (bookingError) {
      console.error(
        `[bobgo] order ${order.id} booking after group payment threw: ${bookingError instanceof Error ? bookingError.message : bookingError}`,
      );
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
        last_message_at: now(),
      },
      { onConflict: "shop_id,buyer_id", ignoreDuplicates: true },
    );

  try {
    await sendInternalPushRequest({
      supabaseUrl: push.supabaseUrl,
      serviceRoleKey: push.serviceRoleKey,
      body: { type: "order_update", orderId: order.id, event: "paid" },
    });
  } catch (pushError) {
    console.error(`[checkout-group] paid push failed order=${order.id}`, pushError);
  }
}

async function loadGroup(admin: SupabaseClient, groupId: string) {
  const { data, error } = await admin
    .from("checkout_groups")
    .select("id, buyer_id, status, buyer_token_id, deposit_expires_at, created_at")
    .eq("id", groupId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data as Group | null;
}

async function loadGroupOrders(admin: SupabaseClient, groupId: string) {
  const { data, error } = await admin
    .from("orders")
    .select(
      "id, buyer_id, shop_id, status, payment_state, shipping_method, tradesafe_transaction_id, tradesafe_buyer_deposit, group_funded_at, bobgo_quote_id, bobgo_provider_slug, bobgo_service_level_code, bobgo_shipment_id, bobgo_booking_state",
    )
    .eq("checkout_group_id", groupId)
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []) as GroupOrder[];
}

async function summarize(admin: SupabaseClient, groupId: string, status: string): Promise<CheckoutGroupResult> {
  const orders = await loadGroupOrders(admin, groupId);
  return {
    groupId,
    status,
    orderIds: orders.map((order) => order.id),
    paidOrderIds: orders
      .filter((order) => order.status !== "pending" && order.status !== "cancelled")
      .map((order) => order.id),
  };
}

/** Takes the group's claim; returns the claim id, or null if someone else holds it. */
async function claimGroup(admin: SupabaseClient, groupId: string, statuses: string[]) {
  const claimId = crypto.randomUUID();
  const cutoff = new Date(Date.now() - FUNDING_CLAIM_MS).toISOString();
  const { data } = await admin
    .from("checkout_groups")
    .update({ funding_claim_id: claimId, funding_claimed_at: now(), updated_at: now() })
    .eq("id", groupId)
    .in("status", statuses)
    .or(`funding_claimed_at.is.null,funding_claimed_at.lt.${cutoff}`)
    .select("id");
  return data && data.length > 0 ? claimId : null;
}

/** Updates the group and releases the claim, only if this run still owns it. */
async function finishGroup(
  admin: SupabaseClient,
  groupId: string,
  claimId: string,
  update: Record<string, unknown>,
) {
  await admin
    .from("checkout_groups")
    .update({ ...update, funding_claim_id: null, funding_claimed_at: null, updated_at: now() })
    .eq("id", groupId)
    .eq("funding_claim_id", claimId);
}

/**
 * Cancels every unpaid order in the basket, returns their stock and cancels
 * their TradeSafe transactions. Never touches an order whose transaction was
 * paid from the wallet. Caller must hold the group's claim.
 */
async function cancelUnpaidGroupOrders(admin: SupabaseClient, orders: GroupOrder[], reason: string) {
  const unpaid = orders.filter((order) => order.status === "pending" && !order.group_funded_at);
  if (unpaid.length === 0) return;
  const { data: cancelled, error } = await admin.rpc("cancel_unpaid_checkout_orders", {
    order_ids: unpaid.map((order) => order.id),
  });
  if (error) throw new Error(error.message);
  for (const row of (cancelled ?? []) as Array<{ order_id: string; tradesafe_transaction_id: string | null }>) {
    if (!row.tradesafe_transaction_id) continue;
    await cancelTradeSafeTransaction(row.tradesafe_transaction_id, reason).catch((cancelError) =>
      console.error(
        `[checkout-group] cancel failed transaction=${row.tradesafe_transaction_id}: ${cancelError instanceof Error ? cancelError.message : cancelError}`,
      )
    );
  }
}

/**
 * Funds every unpaid shop transaction in the group from the buyer's TradeSafe
 * wallet once the basket payment has arrived; expires the basket once its
 * payment window has passed. Returns the group's state.
 */
export async function fundCheckoutGroup(
  admin: SupabaseClient,
  groupId: string,
  push: PushConfig,
  options: { cancelIfUnpaid?: string } = {},
): Promise<CheckoutGroupResult> {
  const group = await loadGroup(admin, groupId);
  if (!group) throw new Error("Checkout not found.");

  if (group.status === "building") {
    // A basket stuck part-way through creation: undo it.
    if (Date.now() - new Date(group.created_at).getTime() < BUILDING_TIMEOUT_MS) {
      return summarize(admin, groupId, "building");
    }
    const claimId = await claimGroup(admin, groupId, ["building"]);
    if (!claimId) return summarize(admin, groupId, "building");
    try {
      await cancelUnpaidGroupOrders(admin, await loadGroupOrders(admin, groupId), "Checkout could not be completed.");
      await finishGroup(admin, groupId, claimId, { status: "cancelled", last_error: "Checkout did not finish." });
      return summarize(admin, groupId, "cancelled");
    } catch (error) {
      await finishGroup(admin, groupId, claimId, { last_error: String(error).slice(0, 500) });
      return summarize(admin, groupId, "building");
    }
  }

  if (group.status !== "awaiting_payment") {
    return summarize(admin, groupId, group.status);
  }

  const claimId = await claimGroup(admin, groupId, ["awaiting_payment"]);
  if (!claimId) return summarize(admin, groupId, "awaiting_payment");

  try {
    const orders = await loadGroupOrders(admin, groupId);
    let balance: number | null = null;
    let allPaid = orders.length > 0;
    let anyFunded = false;

    for (const order of orders) {
      if (order.status === "cancelled") {
        // Cancelled by an admin refund after funding, or never part of it.
        if (order.group_funded_at) anyFunded = true;
        continue;
      }
      if (!order.tradesafe_transaction_id) {
        allPaid = false;
        continue;
      }

      if (order.group_funded_at || order.status !== "pending") {
        anyFunded = true;
        // Already paid from the wallet: only make sure the order shows it.
        if (order.status === "pending") {
          const transaction = await getTradeSafeTransactionState(order.tradesafe_transaction_id);
          if (isTradeSafePaidState(transaction?.state)) {
            await applyPaidOrderEffects(admin, order, transaction!.state, push);
          } else {
            allPaid = false;
          }
        }
        continue;
      }

      // Not funded by us yet. The buyer may have paid this shop some other
      // way (an older payment link), so check TradeSafe first.
      const transaction = await getTradeSafeTransactionState(order.tradesafe_transaction_id);
      if (isTradeSafePaidState(transaction?.state)) {
        await applyPaidOrderEffects(admin, order, transaction!.state, push);
        anyFunded = true;
        continue;
      }

      const due = Number(order.tradesafe_buyer_deposit ?? 0);
      balance ??= await getTradeSafeTokenBalance(group.buyer_token_id);
      if (!(due > 0) || balance + 0.0001 < due) {
        allPaid = false;
        // Funds are allocated in basket order; stop so a later, smaller order
        // never takes money an earlier one needs.
        break;
      }

      const funded = await fundTradeSafeTransactionFromWallet(order.tradesafe_transaction_id);
      balance -= due;
      anyFunded = true;
      await admin.from("orders").update({ group_funded_at: now() }).eq("id", order.id);
      console.log(`[checkout-group] funded group=${groupId} order=${order.id} state=${funded.state}`);
      if (isTradeSafePaidState(funded.state)) {
        await applyPaidOrderEffects(admin, order, funded.state, push);
      } else {
        // TradeSafe has the money but hasn't confirmed yet; the next pass (or
        // its callback) marks the order paid.
        allPaid = false;
      }
    }

    if (allPaid) {
      await finishGroup(admin, groupId, claimId, { status: "funded", funded_at: now(), last_error: null });
      const { data: cart } = await admin.from("carts").select("id").eq("user_id", group.buyer_id).maybeSingle();
      if (cart?.id) {
        await admin.from("cart_items").delete().eq("cart_id", cart.id);
      }
      return summarize(admin, groupId, "funded");
    }

    if (anyFunded) {
      // Part of the basket is paid but not all of it. Should not happen (the
      // payment covers the whole basket); an admin must look at it.
      const expired = group.deposit_expires_at != null &&
        Date.now() > new Date(group.deposit_expires_at).getTime() + PAYMENT_GRACE_MS;
      if (expired) {
        await finishGroup(admin, groupId, claimId, {
          status: "needs_attention",
          last_error: "Only part of the basket could be paid from the buyer's payment.",
        });
        return summarize(admin, groupId, "needs_attention");
      }
      await finishGroup(admin, groupId, claimId, {});
      return summarize(admin, groupId, "awaiting_payment");
    }

    // Nothing paid. Cancel when replaced by a newer basket, or once the
    // payment window has passed. A payment that still arrives later stays in
    // the buyer's TradeSafe wallet and counts towards their next checkout.
    const expired = group.deposit_expires_at == null ||
      Date.now() > new Date(group.deposit_expires_at).getTime() + PAYMENT_GRACE_MS;
    if (options.cancelIfUnpaid || expired) {
      await cancelUnpaidGroupOrders(
        admin,
        orders,
        options.cancelIfUnpaid ?? "Checkout expired before payment was completed.",
      );
      await finishGroup(admin, groupId, claimId, { status: "cancelled", last_error: null });
      return summarize(admin, groupId, "cancelled");
    }

    await finishGroup(admin, groupId, claimId, {});
    return summarize(admin, groupId, "awaiting_payment");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[checkout-group] funding failed group=${groupId}: ${message}`);
    await finishGroup(admin, groupId, claimId, { last_error: message.slice(0, 500) });
    return summarize(admin, groupId, "awaiting_payment");
  }
}

/** Funds or expires every open basket (cron safety net). */
export async function fundOpenCheckoutGroups(admin: SupabaseClient, push: PushConfig) {
  const { data, error } = await admin
    .from("checkout_groups")
    .select("id")
    .in("status", ["building", "awaiting_payment"])
    .gt("created_at", new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString());
  if (error) throw new Error(error.message);
  const funded: string[] = [];
  for (const group of data ?? []) {
    const outcome = await fundCheckoutGroup(admin, group.id as string, push);
    if (outcome.status === "funded") funded.push(outcome.groupId);
  }
  return funded;
}

/**
 * Before a buyer starts a new basket, settles their older open ones: funded
 * if their payment arrived, otherwise cancelled (returning the stock), so two
 * baskets never compete for the same wallet money. Returns what happened.
 */
export async function settleOpenCheckoutGroupsForBuyer(
  admin: SupabaseClient,
  buyerId: string,
  push: PushConfig,
) {
  const { data, error } = await admin
    .from("checkout_groups")
    .select("id")
    .eq("buyer_id", buyerId)
    .in("status", ["building", "awaiting_payment"]);
  if (error) throw new Error(error.message);
  const outcomes: CheckoutGroupResult[] = [];
  for (const group of data ?? []) {
    outcomes.push(
      await fundCheckoutGroup(admin, group.id as string, push, {
        cancelIfUnpaid: "Replaced by a newer checkout.",
      }),
    );
  }
  return {
    // The earlier payment came through: those orders are placed.
    funded: outcomes.filter((outcome) => outcome.status === "funded"),
    // Busy (another request holds it), still being built, or part-paid.
    unsettled: outcomes.filter((outcome) =>
      outcome.status === "awaiting_payment" || outcome.status === "building"
    ),
  };
}
