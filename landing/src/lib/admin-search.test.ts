import { describe, expect, it } from "vitest";

import { getPostgrestSearchTokens } from "./admin-search";

describe("admin search variants", () => {
  it("finds compact shop names when an admin types natural spacing", () => {
    expect(getPostgrestSearchTokens("Knits By Nic")).toEqual(["knit", "nic"]);
  });

  it("removes PostgREST filter punctuation and ignores empty searches", () => {
    expect(getPostgrestSearchTokens("  Clay,(House)  ")).toEqual(["clay", "house"]);
    expect(getPostgrestSearchTokens("   ")).toEqual([]);
  });
});
