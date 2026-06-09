import { NextResponse } from "next/server";

import {
  applyOwnReservations,
  type ProductReservationRow,
} from "@/lib/marketplace/cart-reservation-stock";
import { getMarketplaceProductsByIds } from "@/lib/marketplace/catalog";
import type { GuestCartItem } from "@/lib/marketplace/cart";
import { createAdminClient } from "@/lib/supabase/admin";

function isGuestCartItem(value: unknown): value is GuestCartItem {
  if (value == null || typeof value !== "object") {
    return false;
  }

  const item = value as Partial<GuestCartItem>;
  return (
    typeof item.key === "string" &&
    typeof item.productId === "string" &&
    (typeof item.variantId === "string" || item.variantId === null) &&
    typeof item.quantity === "number" &&
    Number.isFinite(item.quantity) &&
    item.quantity > 0
  );
}

// The cart route only needs product identifiers for hydration, so the
// made-to-order flags carried on guest cart items are ignored here.

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as {
    items?: unknown;
    reservationToken?: unknown;
  } | null;
  const items = Array.isArray(body?.items) ? body.items.filter(isGuestCartItem) : [];
  const products = await getMarketplaceProductsByIds(
    items.map((item) => item.productId),
    { includeOutOfStock: true },
  );
  const reservationToken =
    typeof body?.reservationToken === "string" && body.reservationToken.trim().length > 0
      ? body.reservationToken.trim()
      : null;

  if (!reservationToken || products.length === 0) {
    return NextResponse.json({ products });
  }

  const admin = createAdminClient();
  const { data } = await admin
    .from("product_reservations")
    .select("product_id, variant_id, quantity")
    .eq("reservation_token", reservationToken)
    .eq("status", "active")
    .in(
      "product_id",
      products.map((product) => product.id),
    );

  return NextResponse.json({
    products: applyOwnReservations(products, (data ?? []) as ProductReservationRow[]),
  });
}
