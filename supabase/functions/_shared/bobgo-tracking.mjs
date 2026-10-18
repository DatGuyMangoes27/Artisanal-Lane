// Pure Bob Go tracking helpers. Kept as plain .mjs so they can be unit tested
// with `node --test` and reused by Deno edge functions.
//
// Shapes follow the official Bob Go API reference (Postman collection at
// https://api-docs.bob.co.za/postman-collections/bobgo.postman_collection.json):
//   - tracking/updated webhook: { shipment_tracking_reference, status,
//     status_friendly, checkpoints: [{ status, status_friendly, message, time }] }
//   - shipment topics (shipment_submission_status/updated,
//     shipment_charged_amount/updated, ...): the shipment object { id,
//     tracking_reference, custom_tracking_reference, status, submission_status,
//     failed_reason, charged_amount, time_modified }
//   - GET /tracking: an ARRAY of { shipment_id, short_tracking_reference,
//     custom_tracking_reference, status, tracking_events: [{ status, message,
//     date }] }
// Parsing stays tolerant; anything still unconfirmed in the sandbox is listed
// in docs/bobgo-go-live.md. Unknown statuses are stored verbatim and shown as
// "In progress".

const STATUS_GROUPS = [
  ["delivered", ["delivered", "collected-by-customer"]],
  ["cancelled", ["cancelled", "canceled", "shipment-cancelled"]],
  ["returned", ["returned", "returning", "return-to-sender", "returned-to-sender"]],
  ["exception", [
    "failed-delivery",
    "delivery-failed",
    "exception",
    "failed",
    "delayed",
    "lost",
    "damaged",
    "undeliverable",
    "collection-exception",
    "delivery-exception",
    "failed-collection",
  ]],
  ["out_for_delivery", ["out-for-delivery", "with-delivery-courier", "out-for-delivery-attempt", "ready-for-pickup"]],
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

// Official Bob Go statuses that already-released clients (app 1.3.0 and the
// current website) do not know. orders.bobgo_status stores an alias those
// clients already label correctly; the raw courier status is kept in
// bobgo_tracking_events and the courier's own wording in bobgo_status_detail.
const LEGACY_CLIENT_ALIASES = {
  "collection-exception": "exception",
  "delivery-exception": "exception",
  "failed-collection": "exception",
  "ready-for-pickup": "out-for-delivery",
};

export function normalizeBobGoStatus(raw) {
  if (typeof raw !== "string") return "";
  return raw.trim().toLowerCase().replace(/[_\s]+/g, "-");
}

/** Status to store on orders.bobgo_status (understood by every client build). */
export function canonicalBobGoStatus(raw) {
  const normalized = normalizeBobGoStatus(raw);
  if (!normalized) return null;
  return LEGACY_CLIENT_ALIASES[normalized] ?? normalized;
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

function isObject(value) {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function idOrNull(value) {
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  if (typeof value === "string" && value.trim()) return value.trim();
  return null;
}

function amountOrNull(value) {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * Accepts a tracking/updated webhook body, a shipment-topic webhook body or a
 * GET /tracking response (object or array) and returns a normalized snapshot,
 * or null when no tracking reference/status is found. `fallbackReference` is
 * used for GET /tracking responses that only echo a custom reference.
 * @param {unknown} payload
 * @param {string | null} [fallbackReference]
 */
export function parseBobGoTrackingPayload(payload, fallbackReference = null) {
  if (Array.isArray(payload)) payload = payload.find(isObject) ?? null;
  if (!isObject(payload)) return null;
  const root = isObject(payload.data) ? payload.data : payload;
  const shipment = isObject(root.shipment) ? root.shipment : root;

  const trackingReference = pickString(
    shipment.tracking_reference,
    root.shipment_tracking_reference,
    root.tracking_reference,
    root.short_tracking_reference,
    root.waybill_number,
    fallbackReference,
  );
  if (!trackingReference) return null;

  const rawEvents = [root.checkpoints, root.tracking_events, root.events, shipment.checkpoints]
    .find(Array.isArray) ?? [];
  const events = rawEvents
    .map((event) => ({
      status: pickString(event?.status, event?.status_friendly, event?.tag),
      detail: pickString(event?.message, event?.status_friendly, event?.description, event?.status_detail),
      at: toIso(event?.time ?? event?.date ?? event?.timestamp ?? event?.created_at),
    }))
    .filter((event) => event.status || event.detail)
    .sort((a, b) => (a.at ?? "").localeCompare(b.at ?? ""));

  const latest = events[events.length - 1] ?? null;
  const rawStatus = pickString(shipment.status, root.status, root.tracking_status, latest?.status);
  if (!rawStatus) return null;

  return {
    trackingReference,
    shipmentId: idOrNull(shipment.id) ?? idOrNull(root.shipment_id),
    status: canonicalBobGoStatus(rawStatus),
    rawStatus,
    statusGroup: groupBobGoStatus(rawStatus),
    statusDetail: pickString(
      shipment.status_detail,
      root.status_detail,
      root.status_friendly,
      latest?.detail,
    ),
    trackingUrl: pickString(shipment.tracking_url, root.tracking_url, root.tracking_page_url),
    eventAt: toIso(
      root.updated_at ?? root.event_time ?? latest?.at ?? shipment.time_modified ??
        root.shipment_time_modified,
    ),
    submissionStatus: pickString(shipment.submission_status),
    failedReason: pickString(shipment.failed_reason),
    chargedAmount: amountOrNull(shipment.charged_amount),
    events: events.slice(-25),
  };
}

/** Submission states after which Bob Go will never deliver the shipment. */
export function isFailedBobGoSubmission(submissionStatus) {
  return ["failed-indefinitely", "no-rates"].includes(normalizeBobGoStatus(submissionStatus));
}

/** Length-checked, constant-time comparison for shared secrets. */
export function isValidWebhookSecret(supplied, expected) {
  if (typeof supplied !== "string" || typeof expected !== "string") return false;
  if (!expected || supplied.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= supplied.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

function bytesToBase64(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/**
 * Verifies Bob Go's `Bobgo-Webhook-Signature` header: base64 HMAC-SHA256 of the
 * raw request body keyed with the webhook secret from the Bob Go dashboard
 * (Settings -> Webhook subscriptions). Hex digests are accepted too in case the
 * sandbox differs. Constant-time compare.
 */
export async function verifyBobGoWebhookSignature(rawBody, signature, secret) {
  if (typeof signature !== "string" || !signature.trim() || typeof secret !== "string" || !secret) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody)),
  );
  const supplied = signature.trim().replace(/^sha256=/i, "");
  const base64 = bytesToBase64(digest);
  const hex = Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
  return isValidWebhookSecret(supplied, base64) ||
    isValidWebhookSecret(supplied.toLowerCase(), hex);
}

/**
 * Builds the order update for a tracking snapshot. Returns null when the event
 * is older than what is already stored (out-of-order webhooks), nothing changed
 * (replays), or the order is already delivered/cancelled and the new status
 * disagrees.
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
  if (
    snapshot.eventAt && order.bobgo_last_event_at &&
    new Date(snapshot.eventAt).getTime() === new Date(order.bobgo_last_event_at).getTime() &&
    normalizeBobGoStatus(order.bobgo_status) === normalizeBobGoStatus(snapshot.status)
  ) {
    // Exact replay of the event already stored.
    return null;
  }
  const update = {
    bobgo_status: snapshot.status,
    bobgo_status_detail: snapshot.statusDetail,
    bobgo_last_event_at: snapshot.eventAt ?? now.toISOString(),
  };
  if (snapshot.events.length > 0) update.bobgo_tracking_events = snapshot.events;
  if (snapshot.trackingUrl) {
    update.bobgo_tracking_url = snapshot.trackingUrl;
    update.tracking_url = snapshot.trackingUrl;
  }
  if (snapshot.statusGroup === "delivered") {
    update.bobgo_delivered_at = snapshot.eventAt ?? now.toISOString();
  }
  if (snapshot.chargedAmount != null) {
    update.bobgo_charged_amount = snapshot.chargedAmount;
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
 * Bob Go cancels by tracking reference, so one must be stored.
 */
export function shouldCancelBobGoShipment(order) {
  if (!order || order.shipping_method !== "bobgo_door_to_door") return false;
  if (!order.bobgo_shipment_id || order.bobgo_booking_state !== "booked") return false;
  if (!order.tracking_number) return false;
  if (order.bobgo_cancelled_at || order.bobgo_delivered_at) return false;
  return !["delivered", "cancelled"].includes(groupBobGoStatus(order.bobgo_status));
}

/** Server-side completeness check for an artisan's Bob Go collection details. */
export function isFulfillmentProfileComplete(profile) {
  if (!profile || profile.bobgo_enabled !== true) return false;
  const required = [
    profile.contact_full_name,
    profile.contact_email,
    profile.contact_phone,
    profile.street_address,
    profile.local_area,
    profile.city,
    profile.province,
    profile.postal_code,
  ];
  if (!required.every((value) => typeof value === "string" && value.trim().length > 0)) {
    return false;
  }
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.contact_email.trim()) &&
    profile.contact_phone.replace(/\D/g, "").length >= 9;
}

/** True when every product has positive packed weight and dimensions. */
export function hasParcelMeasurements(product) {
  return [
    product?.shipping_weight_kg,
    product?.shipping_length_cm,
    product?.shipping_width_cm,
    product?.shipping_height_cm,
  ].every((value) => value != null && value !== "" && Number.isFinite(Number(value)) && Number(value) > 0);
}
