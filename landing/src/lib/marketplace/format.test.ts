import { describe, expect, it } from "vitest";

import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "./format";
import type { MarketplaceProduct } from "./types";

const baseProduct: MarketplaceProduct = {
  id: "product-1",
  shopId: "shop-1",
  title: "Handwoven Basket",
  description: "A basket",
  price: 120,
  compareAtPrice: null,
  stockQty: 8,
  images: ["https://example.com/basket.jpg"],
  tags: [],
  shippingOptions: [],
  isFeatured: false,
  createdAt: "2026-05-01T10:00:00.000Z",
  shop: {
    id: "shop-1",
    name: "Artisan Shop",
    slug: "artisan-shop",
    logoUrl: null,
    location: "Cape Town",
    isOffline: false,
  },
  category: null,
  subcategory: null,
  variants: [],
};

describe("marketplace formatting", () => {
  it("formats prices in South African rand", () => {
    expect(formatPrice(120)).toBe("R120.00");
    expect(formatPrice(66.5)).toBe("R66.50");
  });

  it("detects sale products only when compare-at is higher", () => {
    expect(isProductOnSale({ ...baseProduct, compareAtPrice: 150 })).toBe(true);
    expect(isProductOnSale({ ...baseProduct, compareAtPrice: 120 })).toBe(false);
    expect(isProductOnSale({ ...baseProduct, compareAtPrice: null })).toBe(false);
  });

  it("uses the first product image or a safe fallback", () => {
    expect(getProductPrimaryImage(baseProduct)).toBe("https://example.com/basket.jpg");
    expect(getProductPrimaryImage({ ...baseProduct, images: [] })).toBe("/logo.png");
  });

  it("returns useful stock copy", () => {
    expect(getProductStockLabel({ ...baseProduct, stockQty: 0 })).toBe("Out of stock");
    expect(getProductStockLabel({ ...baseProduct, stockQty: 3 })).toBe("Only 3 left");
    expect(getProductStockLabel({ ...baseProduct, stockQty: 8 })).toBe("In stock");
  });
});
