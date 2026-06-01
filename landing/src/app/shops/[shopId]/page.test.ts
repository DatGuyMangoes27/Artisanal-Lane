import React, { isValidElement } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { getMarketplaceShop } from "@/lib/marketplace/catalog";
import {
  getShopReviewSummary,
  listShopMarketEvents,
  listShopPosts,
} from "@/lib/marketplace/shop-profile-data";

import ShopPage, { generateMetadata } from "./page";

vi.mock("@/components/marketplace/marketplace-header", () => ({
  MarketplaceHeader: () =>
    React.createElement("header", { "data-testid": "marketplace-header" }, "Marketplace header"),
}));

vi.mock("@/components/marketplace/product-card", () => ({
  ProductCard: ({ product }: { product: { id: string; title: string } }) =>
    React.createElement("article", { "data-product-card": product.id }, product.title),
}));

vi.mock("@/components/ui/badge", () => ({
  Badge: ({ children }: { children: React.ReactNode }) =>
    React.createElement("span", null, children),
}));

vi.mock("@/components/ui/button", () => ({
  Button: ({ children, ...props }: { children: React.ReactNode }) =>
    React.createElement("button", props, children),
}));

vi.mock("../../account/messages/actions", () => ({
  createBuyerThreadForShop: vi.fn(),
}));

vi.mock("@/lib/marketplace/catalog", () => ({
  getMarketplaceShop: vi.fn(),
}));

vi.mock("@/lib/marketplace/shop-profile-data", () => ({
  getShopReviewSummary: vi.fn(),
  listShopMarketEvents: vi.fn(),
  listShopPosts: vi.fn(),
}));

vi.mock("next/image", () => ({
  default: ({ alt, src }: { alt: string; src: string }) =>
    React.createElement("img", { alt, src }),
}));

vi.mock("next/navigation", () => ({
  notFound: vi.fn(() => {
    throw new Error("NEXT_NOT_FOUND");
  }),
}));

type ReactElementWithChildren = React.ReactElement<{ children?: React.ReactNode }>;

const shop = {
  id: "shop-1",
  name: "Copper & Clay Studio",
  slug: "copper-clay",
  logoUrl: null,
  location: "Cape Town",
  isOffline: false,
  bio: "Hand-built ceramics for everyday rituals.",
  brandStory: "Each piece is shaped in small batches from local clay.",
  coverImageUrl: "https://example.com/cover.jpg",
  shippingOptions: [],
  productCount: 1,
  products: [
    {
      id: "product-1",
      shopId: "shop-1",
      title: "Ochre Mug",
      description: "A warm clay mug.",
      price: 320,
      compareAtPrice: null,
      stockQty: 4,
      images: [],
      tags: [],
      shippingOptions: [],
      isFeatured: false,
      createdAt: "2026-05-12T00:00:00.000Z",
      shop: null,
      category: null,
      subcategory: null,
      variants: [],
    },
  ],
};

function flattenText(node: React.ReactNode): string {
  if (typeof node === "string" || typeof node === "number") {
    return String(node);
  }

  if (Array.isArray(node)) {
    return node.map(flattenText).join(" ");
  }

  if (isValidElement(node)) {
    if (typeof node.type === "function") {
      return flattenText(node.type((node as ReactElementWithChildren).props));
    }

    return flattenText((node as ReactElementWithChildren).props.children);
  }

  return "";
}

describe("shop profile page", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(getMarketplaceShop).mockResolvedValue(shop);
    vi.mocked(getShopReviewSummary).mockResolvedValue({ averageRating: 4.8, reviewCount: 12 });
    vi.mocked(listShopMarketEvents).mockResolvedValue([
      {
        id: "event-1",
        marketName: "Neighbourgoods Market",
        location: "Woodstock",
        eventDate: "2026-06-01",
        timeLabel: "10:00 - 14:00",
        notes: "Find the latest ceramics in person.",
      },
    ]);
    vi.mocked(listShopPosts).mockResolvedValue([
      {
        id: "post-1",
        shopId: "shop-1",
        caption: "Fresh pieces just came out of the kiln.",
        mediaUrls: ["https://example.com/post.jpg"],
        createdAt: "2026-05-12T00:00:00.000Z",
      },
    ]);
  });

  it("loads the requested shop and renders its profile with products", async () => {
    const page = await ShopPage({ params: Promise.resolve({ shopId: "copper-clay" }) });
    const text = flattenText(page);

    expect(getMarketplaceShop).toHaveBeenCalledWith("copper-clay");
    expect(text).toContain("Marketplace header");
    expect(text).toContain("Copper & Clay Studio");
    expect(text).toContain("Cape Town");
    expect(text).toContain("Open for orders");
    expect(text).toContain("Artisan profile");
    expect(text).toContain("Mini profile");
    expect(text).toContain("Hand-built ceramics for everyday rituals.");
    expect(text).toContain("Each piece is shaped in small batches from local clay.");
    expect(text).toContain("Neighbourgoods Market");
    expect(text).toContain("Fresh pieces just came out of the kiln.");
    expect(text).toContain("Ochre Mug");
  });

  it("returns shop metadata and a not-found fallback title", async () => {
    await expect(generateMetadata({ params: Promise.resolve({ shopId: "copper-clay" }) })).resolves.toEqual({
      title: "Copper & Clay Studio | Artisan Lane",
      description: "Hand-built ceramics for everyday rituals.",
    });

    vi.mocked(getMarketplaceShop).mockResolvedValueOnce(null);

    await expect(generateMetadata({ params: Promise.resolve({ shopId: "missing-shop" }) })).resolves.toEqual({
      title: "Shop not found | Artisan Lane",
    });
  });
});
