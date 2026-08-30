import { NextResponse } from "next/server";

import { buildBobGoRateRequest, requestBobGoRates } from "@/lib/bobgo";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

type QuoteBody = {
  items?: Array<{ productId?: unknown; quantity?: unknown }>;
  delivery?: {
    fullName?: unknown;
    email?: unknown;
    phone?: unknown;
    streetAddress?: unknown;
    localArea?: unknown;
    city?: unknown;
    province?: unknown;
    postalCode?: unknown;
  };
};

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function errorResponse(message: string, status = 400) {
  return NextResponse.json({ error: message }, { status });
}

export async function POST(request: Request) {
  const enabled = process.env.BOBGO_SHIPPING_ENABLED === "true" ||
    (process.env.NODE_ENV === "development" && Boolean(process.env.BOBGO_SANDBOX_API_KEY));
  if (!enabled) {
    return errorResponse("Bob Go sandbox shipping is disabled.", 404);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return errorResponse("Sign in to request delivery rates.", 401);

  const body = (await request.json().catch(() => null)) as QuoteBody | null;
  const requestedItems = (body?.items ?? [])
    .map((item) => ({
      productId: text(item.productId),
      quantity: Math.max(0, Math.trunc(Number(item.quantity))),
    }))
    .filter((item) => item.productId && item.quantity > 0);

  if (requestedItems.length === 0) return errorResponse("Your cart is empty.");
  if (requestedItems.reduce((sum, item) => sum + item.quantity, 0) > 20) {
    return errorResponse("Please request a custom delivery quote for more than 20 parcels.");
  }

  const admin = createAdminClient();
  const { data: products, error: productsError } = await admin
    .from("products")
    .select(
      "id, shop_id, title, price, shipping_weight_kg, shipping_length_cm, shipping_width_cm, shipping_height_cm",
    )
    .in("id", requestedItems.map((item) => item.productId))
    .eq("is_published", true)
    .is("archived_at", null);

  if (productsError) return errorResponse("Product parcel measurements are not available yet.", 503);
  if (!products || products.length !== requestedItems.length) {
    return errorResponse("One or more products are unavailable.");
  }

  const shopIds = new Set(products.map((product) => String(product.shop_id)));
  if (shopIds.size !== 1) {
    return errorResponse("Complete each artisan shop checkout separately.");
  }
  const shopId = [...shopIds][0];

  const { data: fulfillment, error: fulfillmentError } = await admin
    .from("shop_fulfillment_profiles")
    .select(
      "contact_full_name, contact_email, contact_phone, company, street_address, local_area, city, province, postal_code, bobgo_enabled",
    )
    .eq("shop_id", shopId)
    .maybeSingle();

  if (fulfillmentError || !fulfillment?.bobgo_enabled) {
    return errorResponse("This artisan has not enabled Bob Go door-to-door delivery.");
  }

  const delivery = body?.delivery;
  const deliveryEmail = text(delivery?.email) || user.email || "";
  try {
    const productMap = new Map(products.map((product) => [String(product.id), product]));
    const parcels = requestedItems.flatMap((item) => {
      const product = productMap.get(item.productId)!;
      const measurements = {
        lengthCm: Number(product.shipping_length_cm),
        widthCm: Number(product.shipping_width_cm),
        heightCm: Number(product.shipping_height_cm),
        weightKg: Number(product.shipping_weight_kg),
      };
      if (Object.values(measurements).some((value) => !Number.isFinite(value) || value <= 0)) {
        throw new Error(`${product.title} needs packed parcel measurements before Bob Go can quote.`);
      }
      return Array.from({ length: item.quantity }, (_, index) => ({
        description: String(product.title),
        ...measurements,
        reference: `${product.id}-${index + 1}`,
      }));
    });

    const rateRequest = buildBobGoRateRequest({
      collectionAddress: {
        company: fulfillment.company,
        streetAddress: fulfillment.street_address,
        localArea: fulfillment.local_area,
        city: fulfillment.city,
        province: fulfillment.province,
        postalCode: fulfillment.postal_code,
      },
      deliveryAddress: {
        streetAddress: text(delivery?.streetAddress),
        localArea: text(delivery?.localArea) || text(delivery?.city),
        city: text(delivery?.city),
        province: text(delivery?.province),
        postalCode: text(delivery?.postalCode),
      },
      collectionContact: {
        fullName: fulfillment.contact_full_name,
        email: fulfillment.contact_email,
        phone: fulfillment.contact_phone,
      },
      deliveryContact: {
        fullName: text(delivery?.fullName),
        email: deliveryEmail,
        phone: text(delivery?.phone),
      },
      parcels,
      declaredValue: requestedItems.reduce((sum, item) => {
        const product = productMap.get(item.productId)!;
        return sum + Number(product.price) * item.quantity;
      }, 0),
    });
    const quote = await requestBobGoRates(rateRequest);
    if (quote.rates.length === 0) {
      return errorResponse("Bob Go returned no door-to-door services for these addresses.", 422);
    }

    const { data: savedQuote, error: quoteError } = await admin
      .from("bobgo_shipping_quotes")
      .insert({
        buyer_id: user.id,
        shop_id: shopId,
        rate_request_id: quote.requestId,
        rates: quote.rates,
        items_snapshot: requestedItems
          .map((item) => ({ productId: item.productId, quantity: item.quantity }))
          .sort((left, right) => left.productId.localeCompare(right.productId)),
        request_snapshot: rateRequest,
      })
      .select("id, expires_at")
      .single();

    if (quoteError || !savedQuote) {
      return errorResponse("The quote was received but could not be saved locally.", 503);
    }

    return NextResponse.json({
      quoteId: savedQuote.id,
      expiresAt: savedQuote.expires_at,
      rates: quote.rates,
    });
  } catch (error) {
    return errorResponse(error instanceof Error ? error.message : "Bob Go quote failed.", 422);
  }
}
