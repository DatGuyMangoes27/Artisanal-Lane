import { describe, expect, it } from "vitest";

import { resolveTrendingSearchTerms } from "./search-trends";

describe("search trend helpers", () => {
  it("deduplicates configured terms before falling back", () => {
    expect(
      resolveTrendingSearchTerms({
        configuredTerms: ["  Ceramics ", "ceramics", "Candles"],
        fallbackTerms: ["Fallback"],
      }),
    ).toEqual(["Ceramics", "Candles"]);
  });

  it("uses fallback terms when no configured terms are available", () => {
    expect(
      resolveTrendingSearchTerms({
        configuredTerms: ["", "  "],
        fallbackTerms: ["Bags", "Textiles"],
        limit: 1,
      }),
    ).toEqual(["Bags"]);
  });
});
