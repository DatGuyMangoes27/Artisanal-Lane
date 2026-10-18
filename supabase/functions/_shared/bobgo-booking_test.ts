import { assertEquals } from "jsr:@std/assert@1";

import { BobGoApiError } from "./bobgo.ts";
import {
  bookBobGoShipmentForOrder,
  type BookingDeps,
  isBobGoBookable,
  reconcileStuckBobGoBooking,
} from "./bobgo-booking.ts";

type Row = Record<string, unknown>;

// Tiny in-memory stand-in for the supabase-js query builder.
function fakeAdmin(orders: Row[], quotes: Row[]) {
  return {
    from(table: string) {
      const rows = table === "orders" ? orders : quotes;
      const filters: Array<(row: Row) => boolean> = [];
      let patch: Row | null = null;
      const run = () => {
        const matched = rows.filter((row) => filters.every((f) => f(row)));
        if (patch) matched.forEach((row) => Object.assign(row, patch));
        return matched;
      };
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
          resolve({ data: run(), error: null });
        },
        maybeSingle() {
          return Promise.resolve({ data: run()[0] ?? null, error: null });
        },
        single() {
          const matched = run();
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
    status: "paid",
    shipping_method: "bobgo_door_to_door",
    shipping_address: { name: "Buyer Corrected", phone: "0821234567" },
    bobgo_quote_id: "quote-1",
    bobgo_provider_slug: "sandbox",
    bobgo_service_level_code: "ECO",
    bobgo_shipment_id: null,
    bobgo_booking_state: "not_requested",
    bobgo_booking_attempts: 0,
    ...overrides,
  };
}

const shipment = (id = "ship-1") => ({
  shipmentId: id,
  status: "pending-collection",
  trackingReference: "TRK1",
  chargedAmount: 90,
  trackingUrl: "https://track.example/TRK1",
});

function deps(overrides: Partial<BookingDeps> = {}) {
  const calls = { create: 0, find: 0, cancel: [] as string[], lastInput: null as unknown };
  const value: BookingDeps = {
    createShipment: (input) => {
      calls.create++;
      calls.lastInput = input;
      return Promise.resolve(shipment());
    },
    findShipment: () => {
      calls.find++;
      return Promise.resolve(null);
    },
    cancelShipment: (reference) => {
      calls.cancel.push(reference);
      return Promise.resolve();
    },
    ...overrides,
  };
  return { value, calls };
}

const quotes = () => [{ id: "quote-1", request_snapshot: {} }];

Deno.test("only bookable Bob Go orders are booked", () => {
  assertEquals(isBobGoBookable(baseOrder() as never), true);
  assertEquals(isBobGoBookable(baseOrder({ shipping_method: "pargo" }) as never), false);
  assertEquals(isBobGoBookable(baseOrder({ bobgo_shipment_id: "x" }) as never), false);
});

Deno.test("books once, records tracking and uses the paid order contact", async () => {
  const order = baseOrder();
  const admin = fakeAdmin([order], quotes());
  const d = deps();

  const first = await bookBobGoShipmentForOrder(admin, order as never, d.value);
  assertEquals(first.outcome, "booked");
  assertEquals(order.bobgo_booking_state, "booked");
  assertEquals(order.tracking_number, "TRK1");
  assertEquals(order.bobgo_tracking_url, "https://track.example/TRK1");
  assertEquals(order.bobgo_charged_amount, 90);
  assertEquals(order.bobgo_booking_attempts, 1);
  // The first attempt never reached Bob Go, so no lookup is needed.
  assertEquals(d.calls.find, 0);
  assertEquals((d.calls.lastInput as { deliveryContact: unknown }).deliveryContact, {
    name: "Buyer Corrected",
    phone: "0821234567",
  });

  const second = await bookBobGoShipmentForOrder(admin, { ...order } as never, d.value);
  assertEquals(second.outcome, "skipped");
  assertEquals(d.calls.create, 1);
});

Deno.test("a concurrent claim does not double book", async () => {
  const order = baseOrder({ bobgo_booking_state: "booking" });
  const d = deps();
  const result = await bookBobGoShipmentForOrder(fakeAdmin([order], quotes()), order as never, d.value);
  assertEquals(result.outcome, "already_claimed");
  assertEquals(d.calls.create, 0);
});

Deno.test("orders that are not paid are never booked", async () => {
  for (const status of ["pending", "cancelled", "completed", "shipped"]) {
    const order = baseOrder({ status });
    const d = deps();
    const result = await bookBobGoShipmentForOrder(fakeAdmin([order], quotes()), order as never, d.value);
    assertEquals(result.outcome, "already_claimed");
    assertEquals(d.calls.create, 0);
  }
});

Deno.test("failures are recorded; a retry looks Bob Go up before booking", async () => {
  const order = baseOrder();
  const admin = fakeAdmin([order], quotes());
  const failing = deps({ createShipment: () => Promise.reject(new Error("courier unavailable")) });
  const failed = await bookBobGoShipmentForOrder(admin, order as never, failing.value);
  assertEquals(failed.outcome, "failed");
  assertEquals(order.bobgo_booking_state, "failed");
  assertEquals(order.bobgo_booking_error, "courier unavailable");
  assertEquals(order.bobgo_booking_attempts, 1);

  const retry = deps();
  const retried = await bookBobGoShipmentForOrder(admin, { ...order } as never, retry.value);
  assertEquals(retried.outcome, "booked");
  assertEquals(retry.calls.find, 1);
  assertEquals(retry.calls.create, 1);
  assertEquals(order.bobgo_booking_attempts, 2);
});

Deno.test("a retry adopts a shipment Bob Go already has instead of booking again", async () => {
  const order = baseOrder({ bobgo_booking_state: "failed", bobgo_booking_attempts: 1 });
  const d = deps({ findShipment: () => Promise.resolve(shipment("existing-7")) });
  const result = await bookBobGoShipmentForOrder(fakeAdmin([order], quotes()), order as never, d.value);
  assertEquals(result.outcome, "booked");
  assertEquals((result as { adopted: boolean }).adopted, true);
  assertEquals(order.bobgo_shipment_id, "existing-7");
  assertEquals(d.calls.create, 0);
});

Deno.test("an ambiguous lookup failure does not book blindly", async () => {
  const order = baseOrder({ bobgo_booking_state: "failed", bobgo_booking_attempts: 1 });
  const d = deps({
    findShipment: () => Promise.reject(new BobGoApiError("timeout", null, true)),
  });
  const result = await bookBobGoShipmentForOrder(fakeAdmin([order], quotes()), order as never, d.value);
  assertEquals(result.outcome, "failed");
  assertEquals(d.calls.create, 0);
  assertEquals(order.bobgo_booking_state, "failed");
  assertEquals(order.bobgo_booking_attempts, 2);
});

Deno.test("an unsupported lookup (4xx) still lets the guarded retry book", async () => {
  const order = baseOrder({ bobgo_booking_state: "failed", bobgo_booking_attempts: 1 });
  const d = deps({
    findShipment: () => Promise.reject(new BobGoApiError("bad query", 400, false)),
  });
  const result = await bookBobGoShipmentForOrder(fakeAdmin([order], quotes()), order as never, d.value);
  assertEquals(result.outcome, "booked");
  assertEquals(d.calls.create, 1);
});

Deno.test("a booking that finishes after a refund is cancelled again", async () => {
  const order = baseOrder();
  const d = deps({
    createShipment: () => {
      order.status = "cancelled"; // the refund lands while Bob Go is booking
      return Promise.resolve(shipment());
    },
  });
  const result = await bookBobGoShipmentForOrder(fakeAdmin([order], quotes()), order as never, d.value);
  assertEquals(result.outcome, "cancelled_after_refund");
  assertEquals(d.calls.cancel, ["TRK1"]);
  assertEquals(order.bobgo_booking_state, "cancelled");
});

Deno.test("stuck bookings are only adopted, never re-booked", async () => {
  const order = baseOrder({ bobgo_booking_state: "booking", bobgo_booking_attempts: 0 });
  const admin = fakeAdmin([order], quotes());
  const none = deps();
  assertEquals(await reconcileStuckBobGoBooking(admin, order as never, none.value), "not_found");
  assertEquals(none.calls.create, 0);
  assertEquals(order.bobgo_booking_state, "booking");

  const found = deps({ findShipment: () => Promise.resolve(shipment("late-1")) });
  assertEquals(await reconcileStuckBobGoBooking(admin, order as never, found.value), "adopted");
  assertEquals(order.bobgo_booking_state, "booked");
  assertEquals(order.bobgo_shipment_id, "late-1");
});
