// Bob Go API client for edge functions.
//
// Endpoints and field names follow the official Bob Go API reference (Postman
// collection linked from https://api-docs.bob.co.za/bobgo):
//   POST /rates                     (see bobgo-rates.ts)
//   POST /shipments                 create (no idempotency key on Bob Go's side)
//   GET  /shipments?tracking_reference=...   lookup (used to avoid duplicates)
//   GET  /shipments/waybill?tracking_references=["REF"]
//   GET  /tracking?tracking_reference=REF    (returns an array)
//   POST /shipments/cancel  { tracking_reference }
// Base URLs: sandbox https://api.sandbox.bobgo.co.za/v2, production
// https://api.bobgo.co.za/v2. Auth: Authorization: Bearer <API key>.

import { isFailedBobGoSubmission, parseBobGoTrackingPayload } from "./bobgo-tracking.mjs";

const DEFAULT_SANDBOX_BASE_URL = "https://api.sandbox.bobgo.co.za/v2";
const REQUEST_TIMEOUT_MS = 25_000;

function bobGoConfig() {
  const apiKey = Deno.env.get("BOBGO_SANDBOX_API_KEY");
  if (!apiKey) throw new Error("BOBGO_SANDBOX_API_KEY is not configured.");
  const baseUrl = (Deno.env.get("BOBGO_SANDBOX_BASE_URL") || DEFAULT_SANDBOX_BASE_URL)
    .replace(/\/+$/, "");
  return { apiKey, baseUrl };
}

/**
 * Server-side switch for NEW Bob Go checkouts (quotes and create-checkout).
 * Off unless explicitly "true".
 */
export function isBobGoEnabled() {
  return Deno.env.get("BOBGO_SHIPPING_ENABLED") === "true";
}

/**
 * Whether Bob Go credentials exist. Servicing orders that were already paid
 * with Bob Go (booking retries, tracking, waybills, cancellation) depends on
 * this, not on the checkout flag, so switching the flag off as a rollback
 * never strands an order that is already in flight.
 */
export function isBobGoConfigured() {
  return Boolean(Deno.env.get("BOBGO_SANDBOX_API_KEY"));
}

/** Error from a Bob Go call. `ambiguous` = Bob Go may have acted anyway. */
export class BobGoApiError extends Error {
  constructor(message: string, readonly status: number | null, readonly ambiguous: boolean) {
    super(message);
    this.name = "BobGoApiError";
  }
}

async function bobGoFetch(path: string, init: RequestInit = {}) {
  const { apiKey, baseUrl } = bobGoConfig();
  try {
    return await fetch(`${baseUrl}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        Accept: "application/json",
        ...(init.body ? { "Content-Type": "application/json" } : {}),
        ...(init.headers ?? {}),
      },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    // Network failure or timeout: the request may or may not have reached Bob Go.
    const reason = error instanceof Error ? error.name : "network error";
    throw new BobGoApiError(`Bob Go request failed (${reason}).`, null, true);
  }
}

async function readJson(response: Response) {
  return await response.json().catch(() => null) as unknown;
}

function errorReason(payload: unknown) {
  if (payload && typeof payload === "object") {
    const record = payload as Record<string, unknown>;
    for (const key of ["failed_reason", "message", "error", "detail"]) {
      const value = record[key];
      if (typeof value === "string" && value.trim()) return value.trim().slice(0, 300);
    }
  }
  return null;
}

type RateRequestSnapshot = {
  collection_address?: unknown;
  delivery_address?: unknown;
  parcels?: unknown;
  collection_contact_full_name?: unknown;
  collection_contact_mobile_number?: unknown;
  collection_contact_email?: unknown;
  delivery_contact_full_name?: unknown;
  delivery_contact_mobile_number?: unknown;
  delivery_contact_email?: unknown;
  declared_value?: unknown;
};

export type DeliveryContactOverride = { name?: string | null; phone?: string | null };

function requiredText(value: unknown, field: string) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`Bob Go ${field} is missing.`);
  }
  return value.trim();
}

function nonEmpty(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

/**
 * Shipment request built from the quote the buyer paid for. The delivery
 * contact name/phone come from the paid order when present (the buyer may have
 * corrected them after quoting; the address itself is verified to match the
 * quote by create-checkout).
 */
export function buildBobGoShipmentRequest(input: {
  orderId: string;
  providerSlug: string;
  serviceLevelCode: string;
  rateRequestSnapshot: RateRequestSnapshot;
  deliveryContact?: DeliveryContactOverride | null;
}) {
  const snapshot = input.rateRequestSnapshot;
  if (!snapshot.collection_address || !snapshot.delivery_address) {
    throw new Error("Bob Go shipment addresses are missing from the saved quote.");
  }
  if (!Array.isArray(snapshot.parcels) || snapshot.parcels.length === 0) {
    throw new Error("Bob Go shipment parcels are missing from the saved quote.");
  }
  const declaredValue = Number(snapshot.declared_value);
  if (!Number.isFinite(declaredValue) || declaredValue <= 0) {
    throw new Error("Bob Go shipment declared value is invalid.");
  }

  return {
    collection_address: snapshot.collection_address,
    // Shipments use *_contact_name; rate requests use *_contact_full_name.
    collection_contact_name: requiredText(
      snapshot.collection_contact_full_name,
      "collection contact name",
    ),
    collection_contact_mobile_number: requiredText(
      snapshot.collection_contact_mobile_number,
      "collection phone",
    ),
    collection_contact_email: requiredText(
      snapshot.collection_contact_email,
      "collection email",
    ),
    delivery_address: snapshot.delivery_address,
    delivery_contact_name: requiredText(
      nonEmpty(input.deliveryContact?.name) ?? snapshot.delivery_contact_full_name,
      "delivery contact name",
    ),
    delivery_contact_mobile_number: requiredText(
      nonEmpty(input.deliveryContact?.phone) ?? snapshot.delivery_contact_mobile_number,
      "delivery phone",
    ),
    delivery_contact_email: requiredText(
      snapshot.delivery_contact_email,
      "delivery email",
    ),
    parcels: snapshot.parcels,
    declared_value: declaredValue,
    timeout: 20000,
    // The order id is our reference on Bob Go; it is how a lost response is
    // found again (findBobGoShipmentForOrder) instead of booking twice.
    custom_tracking_reference: input.orderId,
    custom_order_number: input.orderId,
    service_level_code: requiredText(input.serviceLevelCode, "service level"),
    provider_slug: requiredText(input.providerSlug, "provider"),
  };
}

export type BobGoShipment = {
  shipmentId: string;
  status: string;
  trackingReference: string | null;
  chargedAmount: number | null;
  trackingUrl: string | null;
};

function amountOrNull(value: unknown) {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/** Normalizes a shipment object from POST /shipments or GET /shipments. */
export function parseBobGoShipment(payload: unknown): BobGoShipment | null {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const record = payload as Record<string, unknown>;
  const id = record.id;
  if (id == null || id === "") return null;
  return {
    shipmentId: String(id),
    status: nonEmpty(record.status) ?? "submitted",
    trackingReference: nonEmpty(record.tracking_reference),
    chargedAmount: amountOrNull(record.charged_amount),
    trackingUrl: nonEmpty(record.tracking_url),
  };
}

function shipmentList(payload: unknown): Record<string, unknown>[] {
  if (Array.isArray(payload)) return payload.filter((row) => row && typeof row === "object");
  if (payload && typeof payload === "object") {
    const record = payload as Record<string, unknown>;
    for (const key of ["shipments", "results", "data", "items"]) {
      if (Array.isArray(record[key])) return shipmentList(record[key]);
    }
    if (record.id != null) return [record];
  }
  return [];
}

export async function createBobGoShipment(input: {
  orderId: string;
  providerSlug: string;
  serviceLevelCode: string;
  rateRequestSnapshot: RateRequestSnapshot;
  deliveryContact?: DeliveryContactOverride | null;
}): Promise<BobGoShipment> {
  const body = JSON.stringify(buildBobGoShipmentRequest(input));
  const response = await bobGoFetch("/shipments", { method: "POST", body });
  const payload = await readJson(response) as Record<string, unknown> | null;
  if (!response.ok) {
    throw new BobGoApiError(
      errorReason(payload) || `Bob Go shipment booking failed with status ${response.status}.`,
      response.status,
      // 5xx / 429: Bob Go may have created it; 4xx: it refused the request.
      response.status >= 500 || response.status === 429,
    );
  }
  const shipment = parseBobGoShipment(payload);
  if (!shipment) {
    throw new BobGoApiError("Bob Go accepted the booking but returned no shipment id.", response.status, true);
  }
  if (isFailedBobGoSubmission(payload?.submission_status)) {
    throw new BobGoApiError(
      errorReason(payload) || "Bob Go could not submit the shipment to the courier.",
      response.status,
      false,
    );
  }
  return shipment;
}

/**
 * Finds a live (not cancelled / not failed) shipment previously created for
 * this order, matched on our custom reference. Used before every booking
 * attempt so a lost response can never become a second courier booking.
 * Returns null when none is found.
 */
export async function findBobGoShipmentForOrder(orderId: string): Promise<BobGoShipment | null> {
  const response = await bobGoFetch(
    `/shipments?tracking_reference=${encodeURIComponent(orderId)}&limit=20`,
  );
  if (response.status === 404) return null;
  const payload = await readJson(response);
  if (!response.ok) {
    throw new BobGoApiError(
      `Bob Go shipment lookup failed with status ${response.status}.`,
      response.status,
      true,
    );
  }
  for (const row of shipmentList(payload)) {
    const matchesOrder = row.custom_tracking_reference === orderId ||
      row.custom_order_number === orderId || row.channel_order_number === orderId;
    if (!matchesOrder) continue;
    if (String(row.status ?? "").toLowerCase() === "cancelled") continue;
    if (isFailedBobGoSubmission(row.submission_status)) continue;
    const shipment = parseBobGoShipment(row);
    if (shipment) return shipment;
  }
  return null;
}

/** GET /tracking?tracking_reference=... -> normalized snapshot (or null). */
export async function getBobGoTracking(trackingReference: string) {
  const response = await bobGoFetch(
    `/tracking?tracking_reference=${encodeURIComponent(trackingReference)}`,
  );
  const payload = await readJson(response);
  if (!response.ok) {
    throw new BobGoApiError(
      `Bob Go tracking lookup failed with status ${response.status}.`,
      response.status,
      false,
    );
  }
  return parseBobGoTrackingPayload(payload, trackingReference);
}

function base64ToBytes(value: string) {
  const binary = atob(value.replace(/^data:[^,]+,/, ""));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * GET /shipments/waybill?tracking_references=["REF"] -> PDF bytes. The docs do
 * not show the response, so both a raw PDF and a JSON body carrying a download
 * URL or base64 PDF are accepted.
 */
export async function fetchBobGoWaybill(trackingReference: string) {
  const references = encodeURIComponent(JSON.stringify([trackingReference]));
  const response = await bobGoFetch(
    `/shipments/waybill?tracking_references=${references}&paper_size=A4`,
    { headers: { Accept: "application/pdf, application/json" } },
  );
  if (!response.ok) {
    throw new BobGoApiError(`Bob Go waybill lookup failed with status ${response.status}.`, response.status, false);
  }
  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.includes("json")) {
    return {
      bytes: new Uint8Array(await response.arrayBuffer()),
      contentType: contentType || "application/pdf",
    };
  }

  const payload = await readJson(response) as Record<string, unknown> | string | null;
  const record = typeof payload === "object" && payload ? payload : {};
  const url = typeof payload === "string"
    ? payload
    : nonEmpty(record.url) ?? nonEmpty(record.download_url) ?? nonEmpty(record.waybill_url) ??
      nonEmpty(record.link);
  const inline = nonEmpty(record.base64) ?? nonEmpty(record.pdf) ?? nonEmpty(record.file);
  if (inline) return { bytes: base64ToBytes(inline), contentType: "application/pdf" };
  if (url && /^https:\/\//i.test(url)) {
    const file = await fetch(url, { signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) });
    if (!file.ok) {
      throw new BobGoApiError(`Bob Go waybill download failed with status ${file.status}.`, file.status, false);
    }
    return {
      bytes: new Uint8Array(await file.arrayBuffer()),
      contentType: file.headers.get("content-type") ?? "application/pdf",
    };
  }
  throw new BobGoApiError("Bob Go returned no waybill file.", response.status, false);
}

/**
 * POST /shipments/cancel { tracking_reference }. Each courier's cancellation
 * policy applies; a refusal (e.g. already collected) comes back as a 4xx.
 */
export async function cancelBobGoShipment(trackingReference: string) {
  const response = await bobGoFetch("/shipments/cancel", {
    method: "POST",
    body: JSON.stringify({ tracking_reference: trackingReference }),
  });
  if (!response.ok) {
    const payload = await readJson(response);
    throw new BobGoApiError(
      errorReason(payload) || `Bob Go shipment cancellation failed with status ${response.status}.`,
      response.status,
      response.status >= 500,
    );
  }
}
