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
      {
        key: "product-1",
        productId: "product-1",
        variantId: null,
        quantity: 2,
        isMadeToOrder: false,
        customNote: null,
      },
      {
        key: "product-2:variant-1:mto",
        productId: "product-2",
        variantId: "variant-1",
        quantity: 1,
        isMadeToOrder: true,
        customNote: "Personalised colours",
      },
    ];

    expect(deserializeGuestCartItems(serializeGuestCartItems(items))).toEqual(items);
  });

  it("normalises legacy stored items without made-to-order fields", () => {
    const legacy = JSON.stringify([
      { key: "product-1", productId: "product-1", variantId: null, quantity: 2 },
    ]);

    expect(deserializeGuestCartItems(legacy)).toEqual([
      {
        key: "product-1",
        productId: "product-1",
        variantId: null,
        quantity: 2,
        isMadeToOrder: false,
        customNote: null,
      },
    ]);
  });
});
