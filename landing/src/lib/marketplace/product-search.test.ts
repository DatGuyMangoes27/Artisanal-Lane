import { describe, expect, it } from "vitest";

import {
  matchSearchWord,
  productSearchScore,
  rankProductSearch,
  searchCandidateTerms,
  searchWords,
  singularSearchWord,
  type SearchableProduct,
} from "./product-search";

type Item = SearchableProduct & { id: string };

const item = (id: string, title: string, extra: Partial<SearchableProduct> = {}): Item => ({ id, title, ...extra });

// Newest first, irrelevant pieces first, as the database returns them.
const catalogue: Item[] = [
  item("santa", "Santa tree hanger – white", { description: "Hangs from strings.", shop: { name: "KnitbyNic" } }),
  item("hoops", "Sweet Panda Hoops", {
    description: "Cute clay earrings.",
    shop: { name: "h.of.clay" },
    category: { name: "Jewellery" },
    subcategory: { name: "Earrings" },
  }),
  item("sunflower", "Sunflower soul", { description: "Pairs well with a necklace.", shop: { name: "Vintage Art Bottles" } }),
  item("spring", "Spring wreath"),
  item("pendant", "Copper Pendant Necklace", { shop: { name: "Copper & Co" }, subcategory: { name: "Necklaces" } }),
  item("silver", "Silver Stacking Ring", { shop: { name: "Copper & Co" }, subcategory: { name: "Rings" } }),
  item("moon", "Moon band", { tags: ["rings", "moon"] }),
  item("towel", "Tea towel", { shop: { name: "Rings by Lu" } }),
];

const ids = (items: Item[]) => items.map((entry) => entry.id);

describe("product search relevance", () => {
  it("matches plurals and prefixes but never inside another word", () => {
    expect(matchSearchWord("rings", ["ring"])).toBe(2);
    expect(matchSearchWord("ring", ["rings"])).toBe(2);
    expect(matchSearchWord("neckla", ["necklace"])).toBe(1);
    expect(matchSearchWord("rings", ["earrings"])).toBe(0);
    expect(matchSearchWord("rings", ["strings"])).toBe(0);
    expect(matchSearchWord("ring", ["spring"])).toBe(0);
    expect(singularSearchWord("boxes")).toBe("box");
    expect(singularSearchWord("accessories")).toBe("accessory");
    expect(singularSearchWord("glass")).toBe("glass");
  });

  it("splits words on punctuation", () => {
    expect(searchWords("Santa tree-hanger – WHITE")).toEqual(["santa", "tree", "hanger", "white"]);
  });

  it('ranks "rings" title > tags/subcategory > shop and drops substring hits', () => {
    expect(ids(rankProductSearch(catalogue, "rings"))).toEqual(["silver", "moon", "towel"]);
  });

  it('puts the necklace before description-only matches for "neckla"', () => {
    expect(ids(rankProductSearch(catalogue, "neckla"))).toEqual(["pendant", "sunflower"]);
  });

  it("requires every query word to match", () => {
    expect(ids(rankProductSearch(catalogue, "copper ring"))).toEqual(["silver"]);
    expect(rankProductSearch(catalogue, "necklace dragon")).toEqual([]);
  });

  it("keeps incoming order for ties and matches nothing for empty queries", () => {
    const a = item("a", "Clay mug");
    const b = item("b", "Clay mug");
    expect(ids(rankProductSearch([b, a], "mug"))).toEqual(["b", "a"]);
    expect(rankProductSearch(catalogue, "  ")).toEqual([]);
    expect(productSearchScore(catalogue[0]!, "")).toBe(0);
  });

  it("builds filter-safe candidate terms", () => {
    expect(searchCandidateTerms("Rings, (necklaces)%")).toEqual({
      words: ["rings", "necklaces"],
      stems: ["ring", "necklace"],
      tags: ["rings", "necklaces", "ring", "necklace"],
    });
  });
});
