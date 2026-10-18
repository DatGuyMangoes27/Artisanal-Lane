import type { createAdminClient } from "@/lib/supabase/admin";

// Server-side rules for offering Bob Go on a cart. Mirrors the bobgo-quote
// Edge Function used by the app (isFulfillmentProfileComplete /
// hasParcelMeasurements in supabase/functions/_shared/bobgo-tracking.mjs), so
// web and app offer Bob Go for exactly the same carts.

/** Server switch for new Bob Go checkouts on the website. */
export function isBobGoCheckoutEnabled() {
  return process.env.BOBGO_SHIPPING_ENABLED === "true" ||
    (process.env.NODE_ENV === "development" && Boolean(process.env.BOBGO_SANDBOX_API_KEY));
}

/**
 * Whether Bob Go credentials exist. Servicing orders already paid with Bob Go
 * (waybill download) depends on this, not on the checkout flag, so turning the
 * flag off never strands an order in flight.
 */
export function isBobGoConfigured() {
  return Boolean(process.env.BOBGO_SANDBOX_API_KEY);
}

export type FulfillmentProfileRow = {
  contact_full_name?: string | null;
  contact_email?: string | null;
  contact_phone?: string | null;
  company?: string | null;
  street_address?: string | null;
  local_area?: string | null;
  city?: string | null;
  province?: string | null;
  postal_code?: string | null;
  bobgo_enabled?: boolean | null;
};

export function isFulfillmentProfileComplete(profile: FulfillmentProfileRow | null | undefined) {
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
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(profile.contact_email).trim()) &&
    String(profile.contact_phone).replace(/\D/g, "").length >= 9;
}

export type ParcelProductRow = {
  shipping_weight_kg?: unknown;
  shipping_length_cm?: unknown;
  shipping_width_cm?: unknown;
  shipping_height_cm?: unknown;
};

export function hasParcelMeasurements(product: ParcelProductRow | null | undefined) {
  return [
    product?.shipping_weight_kg,
    product?.shipping_length_cm,
    product?.shipping_width_cm,
    product?.shipping_height_cm,
  ].every((value) => value != null && value !== "" && Number.isFinite(Number(value)) && Number(value) > 0);
}

export const MAX_BOBGO_PARCELS = 20;

export type CartItemInput = { productId: string; quantity: number };

/** One entry per cart line (create-checkout compares the saved quote per line). */
export function normalizeCartItems(raw: unknown): CartItemInput[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => {
      const record = (item ?? {}) as { productId?: unknown; quantity?: unknown };
      return {
        productId: typeof record.productId === "string" ? record.productId.trim() : "",
        quantity: Math.max(0, Math.trunc(Number(record.quantity))),
      };
    })
    .filter((item) => item.productId && Number.isFinite(item.quantity) && item.quantity > 0);
}

export type CartProductRow = ParcelProductRow & {
  id: string;
  shop_id: string;
  title: string;
  price: number | string;
};

export type BobGoCartEligibility =
  | { available: false; reason: string }
  | {
    available: true;
    shopId: string;
    products: Map<string, CartProductRow>;
    fulfillment: FulfillmentProfileRow;
  };

/**
 * Decides whether Bob Go can quote this cart without calling Bob Go.
 * `admin` is a service-role Supabase client (collection addresses are private).
 */
export async function checkBobGoCartEligibility(
  admin: ReturnType<typeof createAdminClient>,
  items: CartItemInput[],
): Promise<BobGoCartEligibility> {
  if (!isBobGoCheckoutEnabled()) return { available: false, reason: "Bob Go delivery is not available right now." };
  if (items.length === 0) return { available: false, reason: "Your cart is empty." };
  if (items.reduce((sum, item) => sum + item.quantity, 0) > MAX_BOBGO_PARCELS) {
    return { available: false, reason: "Please request a custom delivery quote for more than 20 parcels." };
  }

  const uniqueIds = [...new Set(items.map((item) => item.productId))];
  const { data: products, error } = await admin
    .from("products")
    .select("id, shop_id, title, price, shipping_weight_kg, shipping_length_cm, shipping_width_cm, shipping_height_cm")
    .in("id", uniqueIds)
    .eq("is_published", true)
    .is("archived_at", null);
  if (error || !products || products.length !== uniqueIds.length) {
    return { available: false, reason: "One or more products are unavailable." };
  }

  const rows = products as CartProductRow[];
  const shopIds = new Set(rows.map((product) => String(product.shop_id)));
  if (shopIds.size !== 1) return { available: false, reason: "Complete each artisan shop checkout separately." };
  const shopId = [...shopIds][0];

  const missing = rows.find((product) => !hasParcelMeasurements(product));
  if (missing) {
    return { available: false, reason: `${missing.title} needs packed parcel measurements before Bob Go can quote.` };
  }

  const { data: fulfillment } = await admin
    .from("shop_fulfillment_profiles")
    .select(
      "contact_full_name, contact_email, contact_phone, company, street_address, local_area, city, province, postal_code, bobgo_enabled",
    )
    .eq("shop_id", shopId)
    .maybeSingle();
  if (!isFulfillmentProfileComplete(fulfillment as FulfillmentProfileRow | null)) {
    return { available: false, reason: "This artisan has not enabled Bob Go door-to-door delivery." };
  }

  return {
    available: true,
    shopId,
    products: new Map(rows.map((product) => [String(product.id), product])),
    fulfillment: fulfillment as FulfillmentProfileRow,
  };
}
