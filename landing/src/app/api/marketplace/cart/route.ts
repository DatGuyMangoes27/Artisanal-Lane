import { NextResponse } from "next/server";

import { getMarketplaceProductsByIds } from "@/lib/marketplace/catalog";
import type { GuestCartItem } from "@/lib/marketplace/cart";

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

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as { items?: unknown } | null;
  const items = Array.isArray(body?.items) ? body.items.filter(isGuestCartItem) : [];
  const products = await getMarketplaceProductsByIds(
    items.map((item) => item.productId),
  );

  return NextResponse.json({ products });
}
