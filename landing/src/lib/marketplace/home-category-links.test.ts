import { describe, expect, it } from "vitest";

import { buildHomeCategoryLinks } from "./home-category-links";

describe("home marketplace category links", () => {
  it("builds shop filter links for every category in the order provided", () => {
    const links = buildHomeCategoryLinks([
      { id: "cat-home", name: "Home", slug: "home" },
      { id: "cat-art", name: "Art & Design", slug: "art-design" },
      { id: "cat-jewellery", name: "Jewellery", slug: "jewellery" },
      { id: "cat-other", name: "Other", slug: "other" },
    ]);

    expect(links).toEqual([
      { label: "Home", href: "/shop?category=cat-home" },
      { label: "Art & Design", href: "/shop?category=cat-art" },
      { label: "Jewellery", href: "/shop?category=cat-jewellery" },
      { label: "Other", href: "/shop?category=cat-other" },
    ]);
  });

  it("skips duplicate category ids", () => {
    const links = buildHomeCategoryLinks([
      { id: "cat-home", name: "Home", slug: "home" },
      { id: "cat-home", name: "Home & Living", slug: "home-living" },
    ]);

    expect(links).toEqual([{ label: "Home", href: "/shop?category=cat-home" }]);
  });
});
