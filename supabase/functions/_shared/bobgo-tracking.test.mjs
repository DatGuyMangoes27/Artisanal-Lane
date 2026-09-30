import test from "node:test";
import assert from "node:assert/strict";

import {
  bobGoStatusLabel,
  buildOrderTrackingUpdate,
  extractRateEta,
  groupBobGoStatus,
  isTerminalBobGoStatus,
  isValidWebhookSecret,
  parseBobGoTrackingPayload,
  shouldCancelBobGoShipment,
} from "./bobgo-tracking.mjs";

test("groups Bob Go statuses regardless of casing and separators", () => {
  assert.equal(groupBobGoStatus("In_Transit"), "in_transit");
  assert.equal(groupBobGoStatus("out for delivery"), "out_for_delivery");
  assert.equal(groupBobGoStatus("DELIVERED"), "delivered");
  assert.equal(groupBobGoStatus("something-new"), "unknown");
  assert.equal(groupBobGoStatus(null), "unknown");
  assert.equal(bobGoStatusLabel("delivered"), "Delivered");
  assert.equal(isTerminalBobGoStatus("cancelled"), true);
  assert.equal(isTerminalBobGoStatus("in-transit"), false);
});

test("parses a webhook body with checkpoints", () => {
  const snapshot = parseBobGoTrackingPayload({
    data: {
      tracking_reference: "TRK123",
      checkpoints: [
        { status: "delivered", time: "2026-09-30T12:00:00Z", message: "Signed by buyer" },
        { status: "collected", time: "2026-09-29T08:00:00Z" },
      ],
    },
  });
  assert.equal(snapshot.trackingReference, "TRK123");
  assert.equal(snapshot.status, "delivered");
  assert.equal(snapshot.statusGroup, "delivered");
  assert.equal(snapshot.statusDetail, "Signed by buyer");
  assert.equal(snapshot.events.length, 2);
  assert.equal(snapshot.events[0].status, "collected");
});

test("returns null when there is no reference or status", () => {
  assert.equal(parseBobGoTrackingPayload({}), null);
  assert.equal(parseBobGoTrackingPayload({ tracking_reference: "X" }), null);
  assert.equal(parseBobGoTrackingPayload(null), null);
});

test("webhook secret comparison", () => {
  assert.equal(isValidWebhookSecret("abc", "abc"), true);
  assert.equal(isValidWebhookSecret("abd", "abc"), false);
  assert.equal(isValidWebhookSecret("ab", "abc"), false);
  assert.equal(isValidWebhookSecret("", ""), false);
  assert.equal(isValidWebhookSecret(undefined, "abc"), false);
});

test("order update ignores stale events and terminal regressions", () => {
  const snapshot = parseBobGoTrackingPayload({
    tracking_reference: "T",
    status: "in-transit",
    updated_at: "2026-09-29T10:00:00Z",
  });
  assert.equal(
    buildOrderTrackingUpdate(
      { bobgo_status: "collected", bobgo_last_event_at: "2026-09-29T11:00:00Z" },
      snapshot,
    ),
    null,
  );
  assert.equal(buildOrderTrackingUpdate({ bobgo_status: "delivered" }, snapshot), null);
  const update = buildOrderTrackingUpdate({ bobgo_status: "submitted" }, snapshot);
  assert.equal(update.bobgo_status, "in-transit");
  assert.equal(update.bobgo_delivered_at, undefined);
});

test("delivered snapshot stamps delivered_at and tracking url", () => {
  const snapshot = parseBobGoTrackingPayload({
    tracking_reference: "T",
    status: "delivered",
    tracking_url: "https://track.example/T",
    updated_at: "2026-09-30T10:00:00Z",
  });
  const update = buildOrderTrackingUpdate({ bobgo_status: "in-transit" }, snapshot);
  assert.equal(update.bobgo_delivered_at, "2026-09-30T10:00:00.000Z");
  assert.equal(update.tracking_url, "https://track.example/T");
});

test("extractRateEta is tolerant of missing fields", () => {
  assert.deepEqual(extractRateEta({}), {
    etaFrom: null,
    etaTo: null,
    etaMinDays: null,
    etaMaxDays: null,
  });
  const eta = extractRateEta({ min_delivery_days: 2, max_delivery_days: 4 });
  assert.equal(eta.etaMinDays, 2);
  assert.equal(eta.etaMaxDays, 4);
});

test("only booked, undelivered Bob Go shipments are cancelled on refund", () => {
  const booked = {
    shipping_method: "bobgo_door_to_door",
    bobgo_shipment_id: "s1",
    bobgo_booking_state: "booked",
    bobgo_status: "in-transit",
  };
  assert.equal(shouldCancelBobGoShipment(booked), true);
  assert.equal(shouldCancelBobGoShipment({ ...booked, bobgo_status: "delivered" }), false);
  assert.equal(shouldCancelBobGoShipment({ ...booked, bobgo_cancelled_at: "2026-01-01" }), false);
  assert.equal(shouldCancelBobGoShipment({ ...booked, bobgo_booking_state: "failed" }), false);
  assert.equal(shouldCancelBobGoShipment({ ...booked, shipping_method: "pargo" }), false);
  assert.equal(shouldCancelBobGoShipment(null), false);
});
