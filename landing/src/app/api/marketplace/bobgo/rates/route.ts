import { NextResponse } from "next/server";

import { buildBobGoRateRequest, requestBobGoRates } from "@/lib/bobgo";
import {
  checkBobGoCartEligibility,
  isBobGoCheckoutEnabled,
  normalizeCartItems,
} from "@/lib/bobgo-eligibility";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

type QuoteBody = {
  items?: unknown;
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

/**
 * Requests VAT-inclusive Bob Go door-to-door rates and saves the quote for 20
 * minutes, bound to buyer, shop, basket and address. create-checkout re-checks
 * all of that and only ever charges the saved rate.
 */
export async function POST(request: Request) {
  if (!isBobGoCheckoutEnabled()) {
    return errorResponse("Bob Go delivery is not available right now.", 404);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return errorResponse("Sign in to request delivery rates.", 401);

  const body = (await request.json().catch(() => null)) as QuoteBody | null;
  const items = normalizeCartItems(body?.items);

  const admin = createAdminClient();
  const eligibility = await checkBobGoCartEligibility(admin, items);
  if (!eligibility.available) return errorResponse(eligibility.reason);
  const { products, fulfillment, shopId } = eligibility;

  const delivery = body?.delivery;
  const deliveryEmail = text(delivery?.email) || user.email || "";
  try {
    const parcels = items.flatMap((item) => {
      const product = products.get(item.productId)!;
      return Array.from({ length: item.quantity }, (_, index) => ({
        description: String(product.title),
        lengthCm: Number(product.shipping_length_cm),
        widthCm: Number(product.shipping_width_cm),
        heightCm: Number(product.shipping_height_cm),
        weightKg: Number(product.shipping_weight_kg),
        reference: `${product.id}-${index + 1}`,
      }));
    });

    const rateRequest = buildBobGoRateRequest({
      collectionAddress: {
        company: fulfillment.company,
        streetAddress: String(fulfillment.street_address),
        localArea: String(fulfillment.local_area),
        city: String(fulfillment.city),
        province: String(fulfillment.province),
        postalCode: String(fulfillment.postal_code),
      },
      deliveryAddress: {
        streetAddress: text(delivery?.streetAddress),
        localArea: text(delivery?.localArea) || text(delivery?.city),
        city: text(delivery?.city),
        province: text(delivery?.province),
        postalCode: text(delivery?.postalCode),
      },
      collectionContact: {
        fullName: String(fulfillment.contact_full_name),
        email: String(fulfillment.contact_email),
        phone: String(fulfillment.contact_phone),
      },
      deliveryContact: {
        fullName: text(delivery?.fullName),
        email: deliveryEmail,
        phone: text(delivery?.phone),
      },
      parcels,
      declaredValue: items.reduce((sum, item) => {
        const product = products.get(item.productId)!;
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
        items_snapshot: items
          .map((item) => ({ productId: item.productId, quantity: item.quantity }))
          .sort((left, right) => left.productId.localeCompare(right.productId)),
        request_snapshot: rateRequest,
      })
      .select("id, expires_at")
      .single();

    if (quoteError || !savedQuote) {
      return errorResponse("We could not save your delivery quote. Please try again.", 503);
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
