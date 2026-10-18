import test from "node:test";
import assert from "node:assert/strict";

import {
  bobGoStatusLabel,
  canonicalBobGoStatus,
  hasParcelMeasurements,
  isFailedBobGoSubmission,
  isFulfillmentProfileComplete,
  verifyBobGoWebhookSignature,
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
    tracking_number: "UAS1",
  };
  assert.equal(shouldCancelBobGoShipment(booked), true);
  assert.equal(shouldCancelBobGoShipment({ ...booked, bobgo_status: "delivered" }), false);
  assert.equal(shouldCancelBobGoShipment({ ...booked, bobgo_cancelled_at: "2026-01-01" }), false);
  assert.equal(shouldCancelBobGoShipment({ ...booked, bobgo_booking_state: "failed" }), false);
  assert.equal(shouldCancelBobGoShipment({ ...booked, shipping_method: "pargo" }), false);
  assert.equal(shouldCancelBobGoShipment(null), false);
  // Bob Go cancels by tracking reference, so one is required.
  assert.equal(shouldCancelBobGoShipment({ ...booked, tracking_number: null }), false);
});

test("parses the documented tracking/updated webhook body", () => {
  const snapshot = parseBobGoTrackingPayload({
    id: 123,
    shipment_tracking_reference: "UASDX44J",
    status: "out-for-delivery",
    status_friendly: "Out for delivery",
    courier_slug: "sandbox",
    checkpoints: [
      { status: "collected", status_friendly: "Collected", time: "2026-10-01T08:00:00Z" },
      { status: "out-for-delivery", message: "With driver", time: "2026-10-02T07:00:00Z" },
    ],
  });
  assert.equal(snapshot.trackingReference, "UASDX44J");
  assert.equal(snapshot.status, "out-for-delivery");
  assert.equal(snapshot.statusGroup, "out_for_delivery");
  assert.equal(snapshot.eventAt, "2026-10-02T07:00:00.000Z");
  assert.equal(snapshot.events.length, 2);
});

test("parses a shipment-topic body (submission status and charged amount)", () => {
  const snapshot = parseBobGoTrackingPayload({
    id: 77,
    tracking_reference: "UAS77",
    custom_tracking_reference: "order-1",
    status: "pending-collection",
    submission_status: "failed-indefinitely",
    failed_reason: "Courier rejected parcel size",
    charged_amount: "132.25",
    time_modified: "2026-10-03T10:00:00Z",
  });
  assert.equal(snapshot.shipmentId, "77");
  assert.equal(snapshot.submissionStatus, "failed-indefinitely");
  assert.equal(isFailedBobGoSubmission(snapshot.submissionStatus), true);
  assert.equal(isFailedBobGoSubmission("failed-will-retry"), false);
  assert.equal(snapshot.chargedAmount, 132.25);
  assert.equal(snapshot.failedReason, "Courier rejected parcel size");
});

test("GET /tracking array responses use the requested reference", () => {
  const snapshot = parseBobGoTrackingPayload(
    [{ status: "in-transit", tracking_events: [{ status: "in-transit", date: "2026-10-01T09:00:00Z" }] }],
    "UASREF",
  );
  assert.equal(snapshot.trackingReference, "UASREF");
  assert.equal(snapshot.eventAt, "2026-10-01T09:00:00.000Z");
  assert.equal(parseBobGoTrackingPayload([], "UASREF"), null);
});

test("official statuses unknown to released clients are stored as known aliases", () => {
  assert.equal(canonicalBobGoStatus("Delivery_Exception"), "exception");
  assert.equal(canonicalBobGoStatus("failed-collection"), "exception");
  assert.equal(canonicalBobGoStatus("ready-for-pickup"), "out-for-delivery");
  assert.equal(canonicalBobGoStatus("in-transit"), "in-transit");
  assert.equal(canonicalBobGoStatus(""), null);
  assert.equal(groupBobGoStatus("collection-exception"), "exception");
});

test("replayed events do not rewrite the order; charged amount updates", () => {
  const order = { bobgo_status: "in-transit", bobgo_last_event_at: "2026-10-01T09:00:00.000Z" };
  const replay = parseBobGoTrackingPayload({ tracking_reference: "T", status: "in-transit", updated_at: "2026-10-01T09:00:00Z" });
  assert.equal(buildOrderTrackingUpdate(order, replay), null);
  const charged = parseBobGoTrackingPayload({
    tracking_reference: "T",
    status: "in-transit",
    charged_amount: 99,
    updated_at: "2026-10-01T10:00:00Z",
  });
  assert.equal(buildOrderTrackingUpdate(order, charged).bobgo_charged_amount, 99);
});

test("webhook HMAC signature (base64 of the raw body)", async () => {
  const body = JSON.stringify({ shipment_tracking_reference: "X", status: "collected" });
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode("s3cret"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = Buffer.from(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)));
  const signature = digest.toString("base64");
  assert.equal(await verifyBobGoWebhookSignature(body, signature, "s3cret"), true);
  assert.equal(await verifyBobGoWebhookSignature(body, digest.toString("hex"), "s3cret"), true);
  assert.equal(await verifyBobGoWebhookSignature(body + " ", signature, "s3cret"), false);
  assert.equal(await verifyBobGoWebhookSignature(body, signature, "other"), false);
  assert.equal(await verifyBobGoWebhookSignature(body, "", "s3cret"), false);
  assert.equal(await verifyBobGoWebhookSignature(body, signature, ""), false);
});

test("Bob Go is only offered with complete collection details and parcels", () => {
  const profile = {
    bobgo_enabled: true,
    contact_full_name: "Thandi",
    contact_email: "thandi@example.com",
    contact_phone: "082 123 4567",
    street_address: "1 Clay Street",
    local_area: "Woodstock",
    city: "Cape Town",
    province: "Western Cape",
    postal_code: "7925",
  };
  assert.equal(isFulfillmentProfileComplete(profile), true);
  assert.equal(isFulfillmentProfileComplete({ ...profile, bobgo_enabled: false }), false);
  assert.equal(isFulfillmentProfileComplete({ ...profile, local_area: "  " }), false);
  assert.equal(isFulfillmentProfileComplete({ ...profile, contact_email: "nope" }), false);
  assert.equal(isFulfillmentProfileComplete({ ...profile, contact_phone: "123" }), false);
  assert.equal(isFulfillmentProfileComplete(null), false);
  const parcel = { shipping_weight_kg: 1.2, shipping_length_cm: 20, shipping_width_cm: 15, shipping_height_cm: "10" };
  assert.equal(hasParcelMeasurements(parcel), true);
  assert.equal(hasParcelMeasurements({ ...parcel, shipping_height_cm: null }), false);
  assert.equal(hasParcelMeasurements({ ...parcel, shipping_weight_kg: 0 }), false);
});
