const DEFAULT_SANDBOX_BASE_URL = "https://api.sandbox.bobgo.co.za/v2";

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

function requiredText(value: unknown, field: string) {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`Bob Go ${field} is missing.`);
  }
  return value.trim();
}

export function buildBobGoShipmentRequest(input: {
  orderId: string;
  providerSlug: string;
  serviceLevelCode: string;
  rateRequestSnapshot: RateRequestSnapshot;
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
      snapshot.delivery_contact_full_name,
      "delivery contact name",
    ),
    delivery_contact_mobile_number: requiredText(
      snapshot.delivery_contact_mobile_number,
      "delivery phone",
    ),
    delivery_contact_email: requiredText(
      snapshot.delivery_contact_email,
      "delivery email",
    ),
    parcels: snapshot.parcels,
    declared_value: declaredValue,
    timeout: 20000,
    custom_tracking_reference: input.orderId,
    custom_order_number: input.orderId,
    service_level_code: requiredText(input.serviceLevelCode, "service level"),
    provider_slug: requiredText(input.providerSlug, "provider"),
  };
}

export async function createBobGoShipment(input: {
  orderId: string;
  providerSlug: string;
  serviceLevelCode: string;
  rateRequestSnapshot: RateRequestSnapshot;
}) {
  const apiKey = Deno.env.get("BOBGO_SANDBOX_API_KEY");
  if (!apiKey) throw new Error("BOBGO_SANDBOX_API_KEY is not configured.");
  const baseUrl = (Deno.env.get("BOBGO_SANDBOX_BASE_URL") ?? DEFAULT_SANDBOX_BASE_URL)
    .replace(/\/+$/, "");
  const response = await fetch(`${baseUrl}/shipments`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(buildBobGoShipmentRequest(input)),
  });
  const payload = await response.json().catch(() => null) as Record<string, unknown> | null;
  if (!response.ok || !payload?.id) {
    const reason = typeof payload?.failed_reason === "string" ? payload.failed_reason : null;
    throw new Error(reason || `Bob Go shipment booking failed with status ${response.status}.`);
  }

  return {
    shipmentId: String(payload.id),
    status: typeof payload.status === "string" ? payload.status : "submitted",
    trackingReference: typeof payload.tracking_reference === "string"
      ? payload.tracking_reference
      : null,
    chargedAmount: Number.isFinite(Number(payload.charged_amount))
      ? Number(payload.charged_amount)
      : null,
  };
}
