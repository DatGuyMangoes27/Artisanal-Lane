import { describe, expect, it } from "vitest";

import {
  addGuestCartItem,
  getGuestCartItemKey,
  getGuestCartQuantity,
  removeGuestCartItem,
  updateGuestCartQuantity,
} from "./cart";

describe("guest cart helpers", () => {
  it("uses product and variant ids as a stable cart key", () => {
    expect(getGuestCartItemKey("product-1", null)).toBe("product-1");
    expect(getGuestCartItemKey("product-1", "variant-1")).toBe("product-1:variant-1");
  });

  it("adds and increments cart quantities", () => {
    const first = addGuestCartItem([], {
      productId: "product-1",
      variantId: null,
      quantity: 1,
    });
    const second = addGuestCartItem(first, {
      productId: "product-1",
      variantId: null,
      quantity: 2,
    });

    expect(second).toEqual([
      {
        key: "product-1",
        productId: "product-1",
        variantId: null,
        quantity: 3,
      },
    ]);
  });

  it("updates, removes, and sums quantities", () => {
    const cart = [
      { key: "product-1", productId: "product-1", variantId: null, quantity: 3 },
      { key: "product-2:v1", productId: "product-2", variantId: "v1", quantity: 2 },
    ];

    expect(getGuestCartQuantity(cart)).toBe(5);
    expect(updateGuestCartQuantity(cart, "product-1", 1)[0].quantity).toBe(1);
    expect(updateGuestCartQuantity(cart, "product-1", 0)).toHaveLength(1);
    expect(removeGuestCartItem(cart, "product-2:v1")).toHaveLength(1);
  });
});
