import { describe, expect, it } from "vitest";

import { applyOwnReservations } from "./cart-reservation-stock";
import type { MarketplaceProduct } from "./types";

const product: MarketplaceProduct = {
  id: "product-1",
  shopId: "shop-1",
  title: "Clay bowl",
  description: null,
  price: 120,
  compareAtPrice: null,
  stockQty: 2,
  images: [],
  tags: [],
  shippingOptions: [],
  isFeatured: false,
  createdAt: "2026-01-01T00:00:00Z",
  shop: null,
  category: null,
  subcategory: null,
  variants: [
    {
      id: "variant-1",
      productId: "product-1",
      displayName: "Blue",
      optionValues: ["Blue"],
      price: 120,
      compareAtPrice: null,
      stockQty: 1,
      images: [],
      isActive: true,
      sortOrder: 0,
    },
  ],
};

describe("applyOwnReservations", () => {
  it("adds the buyer's active product reservation back into available stock", () => {
    const [reservedProduct] = applyOwnReservations([product], [
      { product_id: "product-1", variant_id: null, quantity: 3 },
    ]);

    expect(reservedProduct.stockQty).toBe(5);
  });

  it("adds active variant reservations back to both variant and product stock", () => {
    const [reservedProduct] = applyOwnReservations([product], [
      { product_id: "product-1", variant_id: "variant-1", quantity: 2 },
    ]);

    expect(reservedProduct.stockQty).toBe(4);
    expect(reservedProduct.variants[0]?.stockQty).toBe(3);
  });
});
