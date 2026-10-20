// Bob Go door-to-door quote for the mobile app.
//
// Reads the signed-in buyer's server-side cart (the same source create-checkout
// uses), requests VAT-inclusive rates and saves the quote for 20 minutes bound
// to buyer + shop + basket + delivery address. The app then passes the returned
// quoteId/rate identifiers to create-checkout, exactly like the website.
//
// Body: { action?: "quote" | "availability" | "status", delivery: {...}, shopId? }
//   shopId       -> quote only that shop's items (multi-shop baskets quote per shop)
//   status       -> { enabled: boolean } (server flag only; used by vendor settings)
//   availability -> { available: boolean, reason?: string } without calling Bob Go,
//                   so the app only offers Bob Go when it can actually quote.
// Disabled unless BOBGO_SHIPPING_ENABLED=true.

import { createClient } from "npm:@supabase/supabase-js@2";

import { isBobGoEnabled } from "../_shared/bobgo.ts";
import { buildBobGoRateRequest, requestBobGoRates } from "../_shared/bobgo-rates.ts";
import { getBearerToken, jsonResponse, optionsResponse } from "../_shared/http.ts";
import { isFulfillmentProfileComplete } from "../_shared/bobgo-tracking.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const MAX_PARCELS = 20;

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function fail(message: string, status = 400) {
  return jsonResponse({ error: message }, { status });
}

Deno.serve(async (request) => {
  try {
    if (request.method === "OPTIONS") return optionsResponse();
    // create-checkout also needs the Artisan Lane TradeSafe token for the AGENT
    // shipping fee, so never offer Bob Go without it.
    const enabled = isBobGoEnabled() && Boolean(Deno.env.get("TRADESAFE_ARTISAN_LANE_TOKEN_ID"));

    let user;
    try {
      const client = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: `Bearer ${getBearerToken(request)}` } },
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data, error } = await client.auth.getUser();
      if (error || !data.user) return fail("Sign in to request delivery rates.", 401);
      user = data.user;
    } catch (_) {
      return fail("Sign in to request delivery rates.", 401);
    }

    const body = await request.json().catch(() => null) as
      | { action?: string; delivery?: Record<string, unknown>; shopId?: unknown }
      | null;
    const delivery = body?.delivery ?? {};
    if (body?.action === "status") return jsonResponse({ enabled });
    const availabilityOnly = body?.action === "availability";
    if (!enabled) {
      return availabilityOnly
        ? jsonResponse({ available: false, reason: "disabled" })
        : fail("Bob Go delivery is not available right now.", 404);
    }
    const unavailable = (message: string) =>
      availabilityOnly ? jsonResponse({ available: false, reason: message }) : fail(message);

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: cart } = await admin.from("carts").select("id").eq("user_id", user.id)
      .maybeSingle();
    const { data: cartItems } = cart
      ? await admin
        .from("cart_items")
        .select(
          "product_id, quantity, variant_id, products(id, shop_id, title, price, is_published, archived_at, shipping_weight_kg, shipping_length_cm, shipping_width_cm, shipping_height_cm), product_variants(price)",
        )
        .eq("cart_id", cart.id)
      : { data: null };

    if (!cartItems || cartItems.length === 0) return unavailable("Your basket is empty.");

    // In a multi-shop basket each shop is quoted separately (shopId given).
    const requestedShopId = typeof body?.shopId === "string" && body.shopId.trim()
      ? body.shopId.trim()
      : null;
    const allLines = cartItems.map((item) => ({
      productId: item.product_id as string,
      quantity: Math.max(0, Math.trunc(Number(item.quantity))),
      product: item.products as unknown as Record<string, unknown> | null,
      variantPrice: (item.product_variants as unknown as { price?: number } | null)?.price,
    }));
    const lines = requestedShopId
      ? allLines.filter((line) => String(line.product?.shop_id) === requestedShopId)
      : allLines;
    if (lines.length === 0) return unavailable("Your basket is empty.");

    if (lines.some((line) => !line.product || line.quantity <= 0 || line.product.is_published !== true || line.product.archived_at != null)) {
      return unavailable("One or more products are unavailable.");
    }
    if (lines.reduce((sum, line) => sum + line.quantity, 0) > MAX_PARCELS) {
      return unavailable("Please request a custom delivery quote for more than 20 parcels.");
    }

    const shopIds = new Set(lines.map((line) => String(line.product!.shop_id)));
    if (shopIds.size !== 1) return unavailable("Complete each artisan shop checkout separately.");
    const shopId = [...shopIds][0];

    const { data: fulfillment } = await admin
      .from("shop_fulfillment_profiles")
      .select(
        "contact_full_name, contact_email, contact_phone, company, street_address, local_area, city, province, postal_code, bobgo_enabled",
      )
      .eq("shop_id", shopId)
      .maybeSingle();
    // Only offered when the artisan opted in AND the collection details are
    // complete, so the app never shows a Bob Go option that cannot quote.
    if (!fulfillment || !isFulfillmentProfileComplete(fulfillment)) {
      return unavailable("This artisan has not enabled Bob Go door-to-door delivery.");
    }

    try {
      const parcels = lines.flatMap((line) => {
        const product = line.product!;
        const measurements = {
          lengthCm: Number(product.shipping_length_cm),
          widthCm: Number(product.shipping_width_cm),
          heightCm: Number(product.shipping_height_cm),
          weightKg: Number(product.shipping_weight_kg),
        };
        if (Object.values(measurements).some((value) => !Number.isFinite(value) || value <= 0)) {
          throw new Error(`${product.title} needs packed parcel measurements before Bob Go can quote.`);
        }
        return Array.from({ length: line.quantity }, (_, index) => ({
          description: String(product.title),
          ...measurements,
          reference: `${line.productId}-${index + 1}`,
        }));
      });

      if (availabilityOnly) return jsonResponse({ available: true });

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
          streetAddress: text(delivery.streetAddress),
          localArea: text(delivery.localArea) || text(delivery.city),
          city: text(delivery.city),
          province: text(delivery.province),
          postalCode: text(delivery.postalCode),
        },
        collectionContact: {
          fullName: fulfillment.contact_full_name,
          email: fulfillment.contact_email,
          phone: fulfillment.contact_phone,
        },
        deliveryContact: {
          fullName: text(delivery.fullName),
          email: text(delivery.email) || user.email || "",
          phone: text(delivery.phone),
        },
        parcels,
        declaredValue: lines.reduce(
          (sum, line) => sum + Number(line.variantPrice ?? line.product!.price) * line.quantity,
          0,
        ),
      });

      const quote = await requestBobGoRates(rateRequest);
      if (quote.rates.length === 0) {
        return fail("Bob Go returned no door-to-door services for these addresses.", 422);
      }

      const { data: saved, error: saveError } = await admin
        .from("bobgo_shipping_quotes")
        .insert({
          buyer_id: user.id,
          shop_id: shopId,
          rate_request_id: quote.requestId,
          rates: quote.rates,
          // One entry per cart line, matching what create-checkout compares.
          items_snapshot: lines
            .map((line) => ({ productId: line.productId, quantity: line.quantity }))
            .sort((a, b) => a.productId.localeCompare(b.productId)),
          request_snapshot: rateRequest,
        })
        .select("id, expires_at")
        .single();
      if (saveError || !saved) return fail("We could not save your delivery quote. Please try again.", 503);

      return jsonResponse({ quoteId: saved.id, expiresAt: saved.expires_at, rates: quote.rates });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Bob Go quote failed.";
      return availabilityOnly ? jsonResponse({ available: false, reason: message }) : fail(message, 422);
    }
  } catch (error) {
    console.error("[bobgo-quote] unexpected failure", error instanceof Error ? error.message : error);
    return fail("We could not get delivery rates right now. Please try again.", 500);
  }
});
