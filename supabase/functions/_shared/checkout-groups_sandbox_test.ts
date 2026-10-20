// End-to-end check of multi-shop funding against the TradeSafe SANDBOX (never
// the live API): two shop transactions, one wallet top-up, then
// fundCheckoutGroup. The database is an in-memory stand-in.
//
// Run (sandbox credentials in an env file, never committed):
//   deno test -A --env-file=<sandbox.env> supabase/functions/_shared/checkout-groups_sandbox_test.ts
// The env file needs TRADESAFE_CLIENT_ID, TRADESAFE_CLIENT_SECRET and
// TRADESAFE_GRAPHQL_URL=https://api-developer.tradesafe.dev/graphql.

import { assert, assertEquals } from "jsr:@std/assert@1";

import { fundCheckoutGroup, settleOpenCheckoutGroupsForBuyer } from "./checkout-groups.ts";
import {
  createTradeSafeTransaction,
  ensureTradeSafeToken,
  getTradeSafeBuyerDeposit,
  getTradeSafeTokenBalance,
  getTradeSafeTransactionState,
  tradeSafeRequest,
} from "./tradesafe.ts";

const isSandbox = (Deno.env.get("TRADESAFE_GRAPHQL_URL") ?? "").includes("tradesafe.dev");

type Row = Record<string, unknown>;

/** Just enough of the supabase-js query builder for checkout-groups.ts. */
function fakeAdmin(tables: Record<string, Row[]>) {
  const from = (table: string) => {
    let rows = () => tables[table] ??= [];
    const filters: Array<(row: Row) => boolean> = [];
    let mode: "select" | "update" | "insert" | "upsert" | "delete" = "select";
    let patch: Row = {};
    let wantRows = false;
    const matching = () => rows().filter((row) => filters.every((filter) => filter(row)));
    const run = () => {
      if (mode === "update") {
        const hit = matching();
        hit.forEach((row) => Object.assign(row, patch));
        return { data: wantRows ? hit : null, error: null };
      }
      if (mode === "delete") {
        tables[table] = rows().filter((row) => !filters.every((filter) => filter(row)));
        return { data: null, error: null };
      }
      if (mode === "insert" || mode === "upsert") return { data: null, error: null };
      return { data: matching(), error: null };
    };
    const builder: Record<string, unknown> = {
      select: () => {
        wantRows = true;
        return builder;
      },
      update: (value: Row) => {
        mode = "update";
        patch = value;
        return builder;
      },
      insert: () => {
        mode = "insert";
        return builder;
      },
      upsert: () => {
        mode = "upsert";
        return builder;
      },
      delete: () => {
        mode = "delete";
        return builder;
      },
      eq: (column: string, value: unknown) => {
        filters.push((row) => row[column] === value);
        return builder;
      },
      in: (column: string, values: unknown[]) => {
        filters.push((row) => values.includes(row[column]));
        return builder;
      },
      gt: (column: string, value: string) => {
        filters.push((row) => String(row[column]) > value);
        return builder;
      },
      or: (expression: string) => {
        // Only "col.is.null,col.lt.<iso>" is used.
        const [, column, cutoff] = expression.match(/^(\w+)\.is\.null,\w+\.lt\.(.+)$/) ?? [];
        filters.push((row) => row[column] == null || String(row[column]) < cutoff);
        return builder;
      },
      order: () => builder,
      maybeSingle: () => Promise.resolve({ data: matching()[0] ?? null, error: null }),
      single: () => Promise.resolve({ data: matching()[0] ?? null, error: null }),
      then: (resolve: (value: unknown) => unknown, reject: (error: unknown) => unknown) =>
        Promise.resolve(run()).then(resolve, reject),
    };
    return builder;
  };
  // cancel_unpaid_checkout_orders: cancels pending orders, returns them.
  const rpc = (name: string, args: { order_ids: string[] }) => {
    if (name !== "cancel_unpaid_checkout_orders") throw new Error(`unexpected rpc ${name}`);
    const cancelled = (tables.orders ?? []).filter((row) =>
      args.order_ids.includes(row.id as string) && row.status === "pending"
    );
    cancelled.forEach((row) => Object.assign(row, { status: "cancelled", payment_state: "STALE_CHECKOUT_CANCELLED" }));
    return Promise.resolve({
      data: cancelled.map((row) => ({ order_id: row.id, tradesafe_transaction_id: row.tradesafe_transaction_id })),
      error: null,
    });
  };
  return { from, rpc } as unknown as Parameters<typeof fundCheckoutGroup>[0];
}

async function creditWallet(tokenId: string, value: number) {
  await tradeSafeRequest(
    "tokenUpdateBalance",
    `mutation($id: ID!, $v: Float!) { tokenUpdateBalance(id: $id, value: $v, type: CREDIT, message: "test basket payment") { id } }`,
    { id: tokenId, v: value },
  );
}

async function sellerToken(name: string, run: number) {
  return await ensureTradeSafeToken({
    displayName: `${name} Test`,
    email: `seller-${name.toLowerCase()}-${run}@example.com`,
    mobile: `+2786${String(run).padStart(7, "0")}`,
    idNumber: "8001015009087",
    bankAccount: { bank: "ABSA", accountNumber: `40${String(run).padStart(8, "0")}`, accountType: "CHEQUE" },
    payoutSettings: { interval: "IMMEDIATE", refund: "IMMEDIATE" },
  });
}

const push = { supabaseUrl: "http://127.0.0.1:9", serviceRoleKey: "test" };

/** Two shop orders with their own sandbox transactions, in one basket. */
async function basket(groupId: string, depositExpiresAt: string) {
  const run = Math.floor(Math.random() * 1e6);
  const buyer = await ensureTradeSafeToken({
    displayName: "Basket Buyer",
    email: `buyer-${run}@example.com`,
    mobile: `+2787${String(run).padStart(7, "0")}`,
  });
  const shops = [
    { shopId: "shop-a", amount: 300, token: await sellerToken("ShopA", run) },
    { shopId: "shop-b", amount: 200, token: await sellerToken("ShopB", run + 1) },
  ];
  const orders: Row[] = [];
  for (const [index, shop] of shops.entries()) {
    const transaction = await createTradeSafeTransaction({
      reference: `group-test-${run}-${index}`,
      title: `Group test ${index}`,
      description: `Group test ${shop.shopId}`,
      buyerTokenId: buyer,
      sellerTokenId: shop.token,
      amount: shop.amount,
    });
    orders.push({
      id: `${groupId}-order-${index}`,
      buyer_id: "buyer",
      shop_id: shop.shopId,
      status: "pending",
      payment_state: transaction.transactionState,
      shipping_method: "courier_guy",
      tradesafe_transaction_id: transaction.transactionId,
      tradesafe_buyer_deposit: await getTradeSafeBuyerDeposit(transaction.transactionId),
      group_funded_at: null,
      checkout_group_id: groupId,
      created_at: `2026-10-20T00:00:0${index}Z`,
    });
  }
  const totalDue = orders.reduce((sum, order) => sum + Number(order.tradesafe_buyer_deposit), 0);
  const tables: Record<string, Row[]> = {
    checkout_groups: [{
      id: groupId,
      buyer_id: "buyer",
      status: "awaiting_payment",
      buyer_token_id: buyer,
      deposit_expires_at: depositExpiresAt,
      created_at: new Date().toISOString(),
      funding_claim_id: null,
      funding_claimed_at: null,
    }],
    orders,
    escrow_transactions: [],
    chat_threads: [],
    carts: [{ id: "cart-1", user_id: "buyer" }],
    cart_items: [{ id: "line-1", cart_id: "cart-1" }],
  };
  return { buyer, orders, totalDue, tables, admin: fakeAdmin(tables) };
}

const inHalfAnHour = () => new Date(Date.now() + 30 * 60 * 1000).toISOString();
const sandboxTest = (name: string, fn: () => Promise<void>) =>
  Deno.test({ name, ignore: !isSandbox, sanitizeOps: false, sanitizeResources: false, fn });

sandboxTest("a multi-shop basket paid once funds every shop's own escrow", async () => {
  const { buyer, orders, totalDue, tables, admin } = await basket("group-1", inHalfAnHour());
  assert(totalDue > 500 && totalDue < 510, `buyer owes items plus their half of fees, got ${totalDue}`);

  // Before the payment lands nothing is funded.
  const waiting = await fundCheckoutGroup(admin, "group-1", push);
  assertEquals(waiting.status, "awaiting_payment");
  assertEquals(waiting.paidOrderIds, []);

  // The one basket payment (whole rands) lands in the buyer's wallet.
  await creditWallet(buyer, Math.ceil(totalDue));
  const funded = await fundCheckoutGroup(admin, "group-1", push);
  assertEquals(funded.status, "funded");
  assertEquals(funded.paidOrderIds.sort(), ["group-1-order-0", "group-1-order-1"]);
  assertEquals(tables.cart_items.length, 0, "basket cleared once every shop is paid");
  assert(orders.every((order) => order.group_funded_at != null), "each order records when it was funded");

  for (const order of orders) {
    const state = await getTradeSafeTransactionState(order.tradesafe_transaction_id as string);
    assertEquals(state?.state, "FUNDS_RECEIVED", "each shop's own escrow holds its money");
  }
  const leftover = await getTradeSafeTokenBalance(buyer);
  // Funding from the wallet costs slightly less in fees than the card/EFT
  // quote the deposit was based on, plus whole-rand rounding: the buyer keeps
  // a little, which counts towards their next checkout.
  assert(leftover >= 0 && leftover < 3, `only small change stays in the wallet, got ${leftover}`);

  // Calling again (app polling, cron) never pays twice.
  const again = await fundCheckoutGroup(admin, "group-1", push);
  assertEquals(again.status, "funded");
  assertEquals(await getTradeSafeTokenBalance(buyer), leftover);
});

sandboxTest("an unpaid basket expires as a whole once its payment window has passed", async () => {
  const { orders, admin, tables } = await basket("group-2", new Date(Date.now() - 60 * 60 * 1000).toISOString());
  const outcome = await fundCheckoutGroup(admin, "group-2", push);
  assertEquals(outcome.status, "cancelled");
  assert(orders.every((order) => order.status === "cancelled"), "every shop's order is cancelled together");
  for (const order of orders) {
    const state = await getTradeSafeTransactionState(order.tradesafe_transaction_id as string);
    // TradeSafe spells it with one L.
    assertEquals(state?.state, "CANCELED", "each shop's transaction is cancelled");
  }
  assertEquals(tables.cart_items.length, 1, "the basket is kept for the buyer");
});

sandboxTest("a new basket replaces an unpaid one, but never a paid one", async () => {
  const unpaid = await basket("group-3", inHalfAnHour());
  const replaced = await settleOpenCheckoutGroupsForBuyer(unpaid.admin, "buyer", push);
  assertEquals(replaced.funded.length, 0);
  assertEquals(replaced.unsettled.length, 0);
  assertEquals(unpaid.tables.checkout_groups[0].status, "cancelled");

  const paid = await basket("group-4", inHalfAnHour());
  await creditWallet(paid.buyer, Math.ceil(paid.totalDue));
  const settled = await settleOpenCheckoutGroupsForBuyer(paid.admin, "buyer", push);
  assertEquals(settled.funded.map((group) => group.groupId), ["group-4"], "a payment that came through is honoured");
  assert(paid.orders.every((order) => order.status === "paid"));
});
