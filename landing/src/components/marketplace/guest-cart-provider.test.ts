import { describe, expect, it } from "vitest";

import { deserializeGuestCartItems, serializeGuestCartItems } from "./guest-cart-provider";

describe("guest cart persistence", () => {
  it("safely ignores invalid stored cart payloads", () => {
    expect(deserializeGuestCartItems(null)).toEqual([]);
    expect(deserializeGuestCartItems("not json")).toEqual([]);
    expect(deserializeGuestCartItems(JSON.stringify({ items: [] }))).toEqual([]);
  });

  it("round trips valid guest cart items", () => {
    const items = [
      { key: "product-1", productId: "product-1", variantId: null, quantity: 2 },
      { key: "product-2:variant-1", productId: "product-2", variantId: "variant-1", quantity: 1 },
    ];

    expect(deserializeGuestCartItems(serializeGuestCartItems(items))).toEqual(items);
  });
});
