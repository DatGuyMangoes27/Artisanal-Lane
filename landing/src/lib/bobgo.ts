const DEFAULT_SANDBOX_BASE_URL = "https://api.sandbox.bobgo.co.za/v2";

export type BobGoAddress = {
  company?: string | null;
  streetAddress: string;
  localArea: string;
  city: string;
  province: string;
  postalCode: string;
  countryCode?: "ZA";
};

export type BobGoContact = {
  fullName: string;
  email: string;
  phone: string;
};

export type BobGoParcel = {
  description: string;
  lengthCm: number;
  widthCm: number;
  heightCm: number;
  weightKg: number;
  reference?: string | null;
};

export type BobGoRate = {
  rateResponseId: number;
  providerId: number;
  providerSlug: string;
  providerName: string;
  serviceLevelCode: string;
  serviceLevelName: string;
  description: string;
  serviceType: string;
  deliveryType: "door";
  amount: number;
  amountExcludingVat: number;
  chargedWeightKg: number;
};

type BobGoRateResponse = {
  id?: unknown;
  provider_rate_requests?: Array<{
    rate_response_id?: unknown;
    provider_id?: unknown;
    provider_slug?: unknown;
    provider_name?: unknown;
    status?: unknown;
    responses?: Array<{
      service_level_code?: unknown;
      rate_amount?: unknown;
      rate_amount_excl_vat?: unknown;
      charged_weight_kg?: unknown;
      status?: unknown;
      service_level?: {
        name?: unknown;
        description?: unknown;
        type?: unknown;
        delivery_type?: unknown;
      };
    }>;
  }>;
};

function requiredPositive(value: number, field: string) {
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${field} must be greater than zero.`);
  }
  return value;
}

function requiredText(value: string, field: string) {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error(`${field} is required.`);
  }
  return trimmed;
}

function apiAddress(address: BobGoAddress) {
  return {
    company: address.company?.trim() || "",
    street_address: requiredText(address.streetAddress, "Street address"),
    local_area: requiredText(address.localArea, "Suburb / local area"),
    city: requiredText(address.city, "City"),
    zone: requiredText(address.province, "Province"),
    country: address.countryCode ?? "ZA",
    code: requiredText(address.postalCode, "Postal code"),
  };
}

export function buildBobGoRateRequest(input: {
  collectionAddress: BobGoAddress;
  deliveryAddress: BobGoAddress;
  collectionContact: BobGoContact;
  deliveryContact: BobGoContact;
  parcels: BobGoParcel[];
  declaredValue: number;
}) {
  if (input.parcels.length === 0) {
    throw new Error("At least one parcel is required for a Bob Go quote.");
  }

  return {
    collection_address: apiAddress(input.collectionAddress),
    delivery_address: apiAddress(input.deliveryAddress),
    parcels: input.parcels.map((parcel) => ({
      description: requiredText(parcel.description, "Parcel description"),
      submitted_length_cm: requiredPositive(parcel.lengthCm, "Parcel length"),
      submitted_width_cm: requiredPositive(parcel.widthCm, "Parcel width"),
      submitted_height_cm: requiredPositive(parcel.heightCm, "Parcel height"),
      submitted_weight_kg: requiredPositive(parcel.weightKg, "Parcel weight"),
      ...(parcel.reference?.trim()
        ? { custom_parcel_reference: parcel.reference.trim() }
        : {}),
    })),
    collection_contact_mobile_number: requiredText(
      input.collectionContact.phone,
      "Collection phone",
    ),
    collection_contact_email: requiredText(
      input.collectionContact.email,
      "Collection email",
    ),
    collection_contact_full_name: requiredText(
      input.collectionContact.fullName,
      "Collection contact",
    ),
    delivery_contact_mobile_number: requiredText(
      input.deliveryContact.phone,
      "Delivery phone",
    ),
    delivery_contact_email: requiredText(
      input.deliveryContact.email,
      "Delivery email",
    ),
    delivery_contact_full_name: requiredText(
      input.deliveryContact.fullName,
      "Delivery contact",
    ),
    declared_value: requiredPositive(input.declaredValue, "Declared value"),
    timeout: 10000,
  };
}

export function flattenBobGoDoorRates(payload: BobGoRateResponse): BobGoRate[] {
  const rates: BobGoRate[] = [];

  for (const provider of payload.provider_rate_requests ?? []) {
    if (provider.status !== "success") continue;

    for (const response of provider.responses ?? []) {
      const service = response.service_level;
      const amount = Number(response.rate_amount);
      if (
        response.status !== "success" ||
        service?.delivery_type !== "door" ||
        !Number.isFinite(amount) ||
        amount < 0
      ) {
        continue;
      }

      rates.push({
        rateResponseId: Number(provider.rate_response_id),
        providerId: Number(provider.provider_id),
        providerSlug: String(provider.provider_slug ?? ""),
        providerName: String(provider.provider_name ?? "Courier"),
        serviceLevelCode: String(response.service_level_code ?? ""),
        serviceLevelName: String(service.name ?? response.service_level_code ?? "Delivery"),
        description: String(service.description ?? "Door-to-door delivery"),
        serviceType: String(service.type ?? "standard"),
        deliveryType: "door",
        amount,
        amountExcludingVat: Number(response.rate_amount_excl_vat ?? amount),
        chargedWeightKg: Number(response.charged_weight_kg ?? 0),
      });
    }
  }

  return rates.sort((left, right) => left.amount - right.amount);
}

export async function requestBobGoRates(
  request: ReturnType<typeof buildBobGoRateRequest>,
  options: { apiKey?: string; baseUrl?: string } = {},
) {
  const apiKey = options.apiKey ?? process.env.BOBGO_SANDBOX_API_KEY;
  if (!apiKey) {
    throw new Error("BOBGO_SANDBOX_API_KEY is not configured.");
  }

  const baseUrl = (options.baseUrl ?? process.env.BOBGO_SANDBOX_BASE_URL ?? DEFAULT_SANDBOX_BASE_URL)
    .replace(/\/+$/, "");
  const response = await fetch(`${baseUrl}/rates`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(request),
    cache: "no-store",
  });

  const payload = (await response.json().catch(() => null)) as BobGoRateResponse | null;
  if (!response.ok || !payload) {
    throw new Error(`Bob Go rate request failed with status ${response.status}.`);
  }

  const requestId = Number(payload.id);
  if (!Number.isFinite(requestId)) {
    throw new Error("Bob Go did not return a rate request ID.");
  }

  return {
    requestId,
    rates: flattenBobGoDoorRates(payload),
    raw: payload,
  };
}
