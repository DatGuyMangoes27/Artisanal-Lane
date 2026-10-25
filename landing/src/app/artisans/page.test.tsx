import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ shops: vi.fn() }));
vi.mock("@/lib/marketplace/catalog", () => ({ getMarketplaceShops: mocks.shops }));
vi.mock("@/components/marketplace/marketplace-header", () => ({
  MarketplaceHeader: () => React.createElement("header", null, "HEADER"),
}));
vi.mock("@/components/marketplace/product-carousel", () => ({
  ProductCarousel: () => React.createElement("div", null, "CAROUSEL"),
}));

import ArtisansPage, { dynamic } from "./page";

function shop(index: number, overrides: Record<string, unknown> = {}) {
  return {
    id: `shop-${index}`,
    name: `Shop ${String(index).padStart(2, "0")}`,
    slug: `shop-${index}`,
    logoUrl: `https://cdn.example.com/logo-${index}.jpg`,
    coverImageUrl: `https://cdn.example.com/cover-${index}.jpg`,
    location: "Cape Town",
    isOffline: false,
    isSpotlight: false,
    productCount: 3,
    ...overrides,
  };
}

async function render(params: Record<string, string> = {}) {
  return renderToStaticMarkup(
    await ArtisansPage({ searchParams: Promise.resolve(params) }),
  );
}

describe("artisans directory", () => {
  beforeEach(() => mocks.shops.mockReset());

  it("renders per request so delisted or deleted shops never linger", () => {
    expect(dynamic).toBe("force-dynamic");
  });

  it("shows cover photo cards with logo, name, location and piece count", async () => {
    mocks.shops.mockResolvedValue([
      shop(1, { name: "Blackreefforge", productCount: 1 }),
    ]);
    const html = await render();

    expect(html).toContain('src="https://cdn.example.com/cover-1.jpg"');
    expect(html).toContain('src="https://cdn.example.com/logo-1.jpg"');
    expect(html).toContain('data-cover="image"');
    expect(html).toContain("Blackreefforge");
    expect(html).toContain("Cape Town");
    expect(html).toContain("1 piece");
    expect(html).toContain('href="/shops/shop-1"');
  });

  it("falls back to the branded gradient when a shop has no cover", async () => {
    mocks.shops.mockResolvedValue([
      shop(1, { coverImageUrl: null, logoUrl: null, name: "Amber Weaves" }),
      shop(2, { coverImageUrl: "  ", productCount: 0 }),
    ]);
    const html = await render();

    expect(html.match(/data-cover="fallback"/g)).toHaveLength(2);
    expect(html).not.toContain("cover-");
    expect(html.match(/<img/g)).toHaveLength(1);
    expect(html).toContain("Setting up shop");
  });

  it("keeps 20-per-page pagination for listed artisans", async () => {
    mocks.shops.mockResolvedValue(Array.from({ length: 25 }, (_, i) => shop(i + 1)));

    const first = await render();
    expect(first.match(/data-testid="shop-card"/g)).toHaveLength(20);
    expect(first).toContain("Page 1 of 2");
    expect(first).toContain('href="/artisans?listedPage=2#listed-artisans"');

    const second = await render({ listedPage: "2" });
    expect(second.match(/data-testid="shop-card"/g)).toHaveLength(5);
    expect(second).toContain("Page 2 of 2");
  });
});
