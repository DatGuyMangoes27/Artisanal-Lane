import { assertEquals } from "jsr:@std/assert@1";

import {
  shouldAcceptTradeSafeDelivery,
  shouldStartTradeSafeDelivery,
} from "./order-fulfillment.ts";

Deno.test("TradeSafe delivery starts only for courier-style fulfilment", () => {
  assertEquals(shouldStartTradeSafeDelivery("courier_guy"), true);
  assertEquals(shouldStartTradeSafeDelivery("courier_guy_door_to_door"), true);
  assertEquals(shouldStartTradeSafeDelivery("pargo"), true);
  assertEquals(shouldStartTradeSafeDelivery("market_pickup"), false);
  assertEquals(shouldStartTradeSafeDelivery(null), false);
});

Deno.test("TradeSafe allocations are still accepted when buyer confirms pickup", () => {
  assertEquals(
    shouldAcceptTradeSafeDelivery({
      allocationId: "allocation-1",
      shippingMethod: "market_pickup",
    }),
    true,
  );
  assertEquals(
    shouldAcceptTradeSafeDelivery({
      allocationId: "allocation-1",
      shippingMethod: "courier_guy",
    }),
    true,
  );
  assertEquals(
    shouldAcceptTradeSafeDelivery({
      allocationId: null,
      shippingMethod: "market_pickup",
    }),
    false,
  );
});
