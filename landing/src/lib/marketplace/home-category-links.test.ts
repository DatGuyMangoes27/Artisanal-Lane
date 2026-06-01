import { describe, expect, it } from "vitest";

import { buildHomeCategoryLinks } from "./home-category-links";

describe("home marketplace category links", () => {
  it("builds shop filter links from real category ids in the landing page order", () => {
    const links = buildHomeCategoryLinks([
      { id: "cat-home", name: "Home & Living", slug: "home-living" },
      { id: "cat-jewellery", name: "Jewellery", slug: "jewellery" },
      { id: "cat-art", name: "Art & Design", slug: "art-design" },
    ]);

    expect(links).toEqual([
      { label: "Art & Design", href: "/shop?category=cat-art" },
      { label: "Jewellery", href: "/shop?category=cat-jewellery" },
      { label: "Home & Living", href: "/shop?category=cat-home" },
    ]);
  });
});
