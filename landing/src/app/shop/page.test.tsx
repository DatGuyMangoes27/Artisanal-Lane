import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, it, expect, vi } from "vitest";
const mocks = vi.hoisted(() => ({ products: vi.fn() }));
vi.mock("@/lib/supabase/server", () => ({ createClient: async () => ({ auth: { getUser: async () => ({ data: { user: null } }) } }) }));
vi.mock("@/lib/marketplace/buyer-preferences-data", () => ({ listFavouriteProductIds: async () => [] }));
vi.mock("@/lib/marketplace/catalog", () => ({
  getMarketplaceCategories: async () => [], getMarketplaceSubcategories: async () => [],
  getMarketplaceProducts: mocks.products, getFreshMarketplaceProducts: async () => [],
  getFreshMarketplaceProductCount: async () => 30, getMarketplaceShopCount: async () => 2,
  getMarketplaceProductCount: async () => 60, freshMarketplaceCutoff: () => "2026-09-03T12:00:00.000Z",
}));
vi.mock("@/components/marketplace/product-card", () => ({ ProductCard: ({ product }: { product: { id: string } }) => React.createElement("article", null, product.id) }));
vi.mock("@/components/marketplace/product-carousel", () => ({ ProductCarousel: () => React.createElement("div", null, "CAROUSEL") }));
vi.mock("@/components/marketplace/search-controls", () => ({ SearchControls: () => React.createElement("div", null, "FILTERS") }));
import ShopPage from "./page";
describe("dedicated new arrivals", () => {
  it("renders one grid, newest first, seven-day cutoff and full catalogue link", async () => {
    mocks.products.mockResolvedValue(Array.from({ length: 25 }, (_, i) => ({ id: String(i) })));
    const html = renderToStaticMarkup(await ShopPage({ searchParams: Promise.resolve({ fresh: "7" }) }));
    expect(html).toContain("New <span");
    expect(html).not.toContain("CAROUSEL");
    expect(html).not.toContain("Find the piece");
    expect(html.match(/<article>/g)).toHaveLength(24);
    expect(html).toContain("Showing 1–24");
    expect(html).toContain("View full collection");
    expect(html).toContain("fresh=7");
    expect(mocks.products).toHaveBeenLastCalledWith(expect.objectContaining({ createdAfter: "2026-09-03T12:00:00.000Z", sort: "newest", offset: 0, limit: 25 }));
  });
  it("keeps pagination and filters within the seven-day collection", async () => {
    mocks.products.mockResolvedValue([{ id: "last" }]);
    const html = renderToStaticMarkup(await ShopPage({ searchParams: Promise.resolve({ fresh: "7", page: "2", q: "linen" }) }));
    expect(html).toContain("Showing 25–25");
    expect(html).toContain("Previous");
    expect(html).not.toContain(">Next<");
    expect(mocks.products).toHaveBeenLastCalledWith(expect.objectContaining({ query: "linen", offset: 24, createdAfter: "2026-09-03T12:00:00.000Z" }));
  });
  it("shows an honest empty state", async () => {
    mocks.products.mockResolvedValue([]);
    const html = renderToStaticMarkup(await ShopPage({ searchParams: Promise.resolve({ fresh: "7" }) }));
    expect(html).toContain("No products match these filters.");
    expect(html).not.toContain("Showing 1");
  });
});
