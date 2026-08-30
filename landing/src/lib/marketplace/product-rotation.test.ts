import { describe, expect, it } from "vitest";

import { getDailyProductRotationSeed, rotateProductsForSeed } from "./product-rotation";

const products = ["a", "b", "c", "d", "e", "f"].map((id) => ({ id }));

describe("product rotation", () => {
  it("is deterministic for a given day without mutating the source", () => {
    const originalIds = products.map((product) => product.id);
    const first = rotateProductsForSeed(products, "2026-08-30");
    const second = rotateProductsForSeed(products, "2026-08-30");

    expect(first.map((product) => product.id)).toEqual(second.map((product) => product.id));
    expect(products.map((product) => product.id)).toEqual(originalIds);
  });

  it("changes the mix as the daily seed changes", () => {
    expect(rotateProductsForSeed(products, "2026-08-30")).not.toEqual(
      rotateProductsForSeed(products, "2026-08-31"),
    );
  });

  it("uses a UTC calendar date as the default seed", () => {
    expect(getDailyProductRotationSeed(new Date("2026-08-30T23:59:59Z"))).toBe("2026-08-30");
  });
});
