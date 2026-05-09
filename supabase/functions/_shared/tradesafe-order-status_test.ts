import { assertEquals } from "jsr:@std/assert@1";

import {
  mapTradeSafeEscrowStatus,
  mapTradeSafeOrderStatus,
  shouldIgnoreTradeSafeCallback,
} from "./tradesafe-order-status.ts";

Deno.test("TradeSafe status mapping treats failed checkout states as cancelled", () => {
  assertEquals(mapTradeSafeOrderStatus("FUNDS_RECEIVED"), "paid");
  assertEquals(mapTradeSafeOrderStatus("CANCELLED"), "cancelled");
  assertEquals(mapTradeSafeOrderStatus("FAILED"), "cancelled");
  assertEquals(mapTradeSafeOrderStatus("EXPIRED"), "cancelled");
  assertEquals(mapTradeSafeOrderStatus("CREATED"), "pending");

  assertEquals(mapTradeSafeEscrowStatus("FUNDS_RECEIVED"), "held");
  assertEquals(mapTradeSafeEscrowStatus("EXPIRED"), "cancelled");
  assertEquals(mapTradeSafeEscrowStatus("CREATED"), "pending");
});

Deno.test("late TradeSafe callbacks do not revive locally cancelled stale checkouts", () => {
  assertEquals(
    shouldIgnoreTradeSafeCallback({
      currentOrderStatus: "cancelled",
      currentPaymentState: "STALE_CHECKOUT_CANCELLED",
      incomingTradeSafeState: "FUNDS_RECEIVED",
    }),
    true,
  );

  assertEquals(
    shouldIgnoreTradeSafeCallback({
      currentOrderStatus: "cancelled",
      currentPaymentState: "CANCELLED",
      incomingTradeSafeState: "FUNDS_RECEIVED",
    }),
    false,
  );
});
