import { assertEquals } from "jsr:@std/assert@1";

import { bookBobGoShipmentForOrder, isBobGoBookable } from "./bobgo-booking.ts";

type Row = Record<string, unknown>;

// Tiny in-memory stand-in for the supabase-js query builder.
function fakeAdmin(orders: Row[], quotes: Row[]) {
  return {
    from(table: string) {
      const rows = table === "orders" ? orders : quotes;
      const filters: Array<(row: Row) => boolean> = [];
      let patch: Row | null = null;
      const builder = {
        update(values: Row) {
          patch = values;
          return builder;
        },
        select(_columns: string) {
          return builder;
        },
        eq(column: string, value: unknown) {
          filters.push((row) => row[column] === value);
          return builder;
        },
        in(column: string, values: unknown[]) {
          filters.push((row) => values.includes(row[column]));
          return builder;
        },
        is(column: string, value: unknown) {
          filters.push((row) => (row[column] ?? null) === value);
          return builder;
        },
        // deno-lint-ignore no-explicit-any
        then(resolve: (value: any) => void) {
          const matched = rows.filter((row) => filters.every((f) => f(row)));
          if (patch) matched.forEach((row) => Object.assign(row, patch));
          resolve({ data: matched, error: null });
        },
        maybeSingle() {
          const matched = rows.filter((row) => filters.every((f) => f(row)));
          if (patch) matched.forEach((row) => Object.assign(row, patch));
          return Promise.resolve({ data: matched[0] ?? null, error: null });
        },
        single() {
          const matched = rows.filter((row) => filters.every((f) => f(row)));
          return Promise.resolve(
            matched[0] ? { data: matched[0], error: null } : { data: null, error: { message: "none" } },
          );
        },
      };
      return builder;
    },
  };
}

function baseOrder(overrides: Row = {}): Row {
  return {
    id: "order-1",
    shipping_method: "bobgo_door_to_door",
    bobgo_quote_id: "quote-1",
    bobgo_provider_slug: "sandbox",
    bobgo_service_level_code: "ECO",
    bobgo_shipment_id: null,
    bobgo_booking_state: "not_requested",
    bobgo_booking_attempts: 0,
    ...overrides,
  };
}

const okShipment = () =>
  Promise.resolve({
    shipmentId: "ship-1",
    status: "submitted",
    trackingReference: "TRK1",
    chargedAmount: 90,
    trackingUrl: "https://track.example/TRK1",
  });

Deno.test("only bookable Bob Go orders are booked", () => {
  assertEquals(isBobGoBookable(baseOrder() as never), true);
  assertEquals(isBobGoBookable(baseOrder({ shipping_method: "pargo" }) as never), false);
  assertEquals(isBobGoBookable(baseOrder({ bobgo_shipment_id: "x" }) as never), false);
});

Deno.test("books once and records tracking", async () => {
  const order = baseOrder();
  const admin = fakeAdmin([order], [{ id: "quote-1", request_snapshot: {} }]);
  let calls = 0;
  const deps = { createShipment: () => (calls++, okShipment()) };

  const first = await bookBobGoShipmentForOrder(admin, order as never, deps);
  assertEquals(first.outcome, "booked");
  assertEquals(order.bobgo_booking_state, "booked");
  assertEquals(order.tracking_number, "TRK1");
  assertEquals(order.bobgo_tracking_url, "https://track.example/TRK1");

  const second = await bookBobGoShipmentForOrder(admin, { ...order } as never, deps);
  assertEquals(second.outcome, "skipped");
  assertEquals(calls, 1);
});

Deno.test("a concurrent claim does not double book", async () => {
  const order = baseOrder({ bobgo_booking_state: "booking" });
  const admin = fakeAdmin([order], [{ id: "quote-1", request_snapshot: {} }]);
  let calls = 0;
  const result = await bookBobGoShipmentForOrder(admin, order as never, {
    createShipment: () => (calls++, okShipment()),
  });
  assertEquals(result.outcome, "already_claimed");
  assertEquals(calls, 0);
});

Deno.test("failures are recorded and can be retried", async () => {
  const order = baseOrder();
  const admin = fakeAdmin([order], [{ id: "quote-1", request_snapshot: {} }]);
  const failed = await bookBobGoShipmentForOrder(admin, order as never, {
    createShipment: () => Promise.reject(new Error("courier unavailable")),
  });
  assertEquals(failed.outcome, "failed");
  assertEquals(order.bobgo_booking_state, "failed");
  assertEquals(order.bobgo_booking_error, "courier unavailable");
  assertEquals(order.bobgo_booking_attempts, 1);

  const retried = await bookBobGoShipmentForOrder(admin, { ...order } as never, {
    createShipment: okShipment,
  });
  assertEquals(retried.outcome, "booked");
  assertEquals(order.bobgo_booking_attempts, 2);
});
