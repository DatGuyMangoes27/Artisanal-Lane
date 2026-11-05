import { describe, expect, it } from "vitest";

import { fitWithin } from "./shrink-image";

describe("fitWithin", () => {
  it("leaves photos that already fit untouched", () => {
    expect(fitWithin(1200, 800)).toEqual({ width: 1200, height: 800 });
  });

  it("scales the longest side down to the limit, keeping the shape", () => {
    expect(fitWithin(4032, 3024)).toEqual({ width: 1600, height: 1200 });
    expect(fitWithin(3024, 4032)).toEqual({ width: 1200, height: 1600 });
  });
});
