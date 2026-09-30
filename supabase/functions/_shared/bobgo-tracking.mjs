// Pure Bob Go tracking helpers. Kept as plain .mjs so they can be unit tested
// with `node --test` and reused by Deno edge functions.
//
// NOTE: the exact tracking payload and status vocabulary must be confirmed
// against the Bob Go sandbox (see docs/bobgo-go-live.md). Parsing is
// deliberately tolerant and unknown statuses are stored verbatim and shown as
// "In progress".

const STATUS_GROUPS = [
  ["delivered", ["delivered", "collected-by-customer"]],
  ["cancelled", ["cancelled", "canceled", "shipment-cancelled"]],
  ["returned", ["returned", "returning", "return-to-sender", "returned-to-sender"]],
  ["exception", ["failed-delivery", "delivery-failed", "exception", "failed", "delayed", "lost", "damaged", "undeliverable"]],
  ["out_for_delivery", ["out-for-delivery", "with-delivery-courier", "out-for-delivery-attempt"]],
  ["in_transit", ["in-transit", "in-transit-to-destination", "at-hub", "at-destination-hub", "dispatched", "departed", "arrived"]],
  ["collected", ["collected", "picked-up", "pickup-complete", "collection-complete"]],
  ["awaiting_collection", ["submitted", "pending", "pending-collection", "collection-assigned", "collection-pending", "booked", "created", "confirmed", "ready-for-collection", "awaiting-collection"]],
];

const LABELS = {
  awaiting_collection: "Booked - waiting for courier collection",
  collected: "Collected by the courier",
  in_transit: "On its way",
  out_for_delivery: "Out for delivery",
  delivered: "Delivered",
  exception: "Delivery problem - the courier will retry",
  returned: "Returning to the artisan",
  cancelled: "Courier booking cancelled",
  unknown: "In progress",
};

export function normalizeBobGoStatus(raw) {
  if (typeof raw !== "string") return "";
  return raw.trim().toLowerCase().replace(/[_\s]+/g, "-");
}

export function groupBobGoStatus(raw) {
  const normalized = normalizeBobGoStatus(raw);
  if (!normalized) return "unknown";
  for (const [group, values] of STATUS_GROUPS) {
    if (values.includes(normalized)) return group;
  }
  return "unknown";
}

export function bobGoStatusLabel(raw) {
  return LABELS[groupBobGoStatus(raw)];
}

export function isTerminalBobGoStatus(raw) {
  return ["delivered", "cancelled", "returned"].includes(groupBobGoStatus(raw));
}

function pickString(...values) {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function toIso(value) {
  if (typeof value !== "string" && typeof value !== "number") return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

/**
 * Accepts either a webhook body or a GET /tracking response and returns a
 * normalized snapshot, or null when no tracking reference/status is found.
 */
export function parseBobGoTrackingPayload(payload) {
  if (!payload || typeof payload !== "object") return null;
  const root = payload.data && typeof payload.data === "object" ? payload.data : payload;
  const shipment = root.shipment && typeof root.shipment === "object" ? root.shipment : root;

  const trackingReference = pickString(
    shipment.tracking_reference,
    root.tracking_reference,
    root.waybill_number,
  );
  if (!trackingReference) return null;

  const rawEvents = Array.isArray(root.checkpoints)
    ? root.checkpoints
    : Array.isArray(root.events)
    ? root.events
    : Array.isArray(shipment.checkpoints)
    ? shipment.checkpoints
    : [];
  const events = rawEvents
    .map((event) => ({
      status: pickString(event?.status, event?.status_friendly, event?.tag),
      detail: pickString(event?.message, event?.description, event?.status_detail),
      at: toIso(event?.time ?? event?.date ?? event?.timestamp ?? event?.created_at),
    }))
    .filter((event) => event.status || event.detail)
    .sort((a, b) => (a.at ?? "").localeCompare(b.at ?? ""));

  const latest = events[events.length - 1] ?? null;
  const status = pickString(shipment.status, root.status, root.tracking_status, latest?.status);
  if (!status) return null;

  return {
    trackingReference,
    status,
    statusGroup: groupBobGoStatus(status),
    statusDetail: pickString(shipment.status_detail, root.status_detail, latest?.detail),
    trackingUrl: pickString(shipment.tracking_url, root.tracking_url, root.tracking_page_url),
    eventAt: toIso(root.updated_at ?? root.event_time ?? latest?.at) ?? null,
    events: events.slice(-25),
  };
}

/** Length-checked, constant-time comparison for the shared webhook secret. */
export function isValidWebhookSecret(supplied, expected) {
  if (typeof supplied !== "string" || typeof expected !== "string") return false;
  if (!expected || supplied.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= supplied.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

/**
 * Builds the order update for a tracking snapshot. Returns null when the event
 * is older than what is already stored (out-of-order webhooks) or the order is
 * already delivered/cancelled and the new status disagrees.
 */
export function buildOrderTrackingUpdate(order, snapshot, now = new Date()) {
  if (!snapshot) return null;
  const currentGroup = groupBobGoStatus(order.bobgo_status);
  if (["delivered", "cancelled"].includes(currentGroup) && snapshot.statusGroup !== currentGroup) {
    return null;
  }
  if (
    snapshot.eventAt && order.bobgo_last_event_at &&
    new Date(snapshot.eventAt).getTime() < new Date(order.bobgo_last_event_at).getTime()
  ) {
    return null;
  }
  const update = {
    bobgo_status: snapshot.status,
    bobgo_status_detail: snapshot.statusDetail,
    bobgo_last_event_at: snapshot.eventAt ?? now.toISOString(),
    bobgo_tracking_events: snapshot.events,
  };
  if (snapshot.trackingUrl) {
    update.bobgo_tracking_url = snapshot.trackingUrl;
    update.tracking_url = snapshot.trackingUrl;
  }
  if (snapshot.statusGroup === "delivered") {
    update.bobgo_delivered_at = snapshot.eventAt ?? now.toISOString();
  }
  return update;
}

/** Delivery estimate from a Bob Go rate response, when the courier supplies one. */
export function extractRateEta(response) {
  const service = response?.service_level ?? {};
  const from = pickString(
    response?.delivery_date_from,
    response?.min_delivery_date,
    response?.estimated_delivery_from,
    service.delivery_date_from,
  );
  const to = pickString(
    response?.delivery_date_to,
    response?.max_delivery_date,
    response?.estimated_delivery_to,
    service.delivery_date_to,
  );
  const minDays = Number(response?.min_delivery_days ?? service.min_delivery_days);
  const maxDays = Number(response?.max_delivery_days ?? service.max_delivery_days);
  return {
    etaFrom: toIso(from),
    etaTo: toIso(to),
    etaMinDays: Number.isFinite(minDays) && minDays > 0 ? minDays : null,
    etaMaxDays: Number.isFinite(maxDays) && maxDays > 0 ? maxDays : null,
  };
}

/**
 * Whether a refund/cancellation should try to cancel the booked courier. A
 * delivered shipment cannot be cancelled; one already cancelled needs nothing.
 */
export function shouldCancelBobGoShipment(order) {
  if (!order || order.shipping_method !== "bobgo_door_to_door") return false;
  if (!order.bobgo_shipment_id || order.bobgo_booking_state !== "booked") return false;
  if (order.bobgo_cancelled_at || order.bobgo_delivered_at) return false;
  return !["delivered", "cancelled"].includes(groupBobGoStatus(order.bobgo_status));
}
