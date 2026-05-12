import { beforeEach, describe, expect, it, vi } from "vitest";

import { createClient } from "@/lib/supabase/server";

import { getMarketplaceProducts, getMarketplaceShop } from "./catalog";

vi.mock("server-only", () => ({}));
vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(),
}));

type QueryResult = {
  data: unknown;
  error: Error | null;
};

type SupabaseClientMock = Awaited<ReturnType<typeof createClient>>;

function createQuery(result: QueryResult) {
  const calls: Array<[string, ...unknown[]]> = [];
  const query = {
    calls,
    select: vi.fn((...args: unknown[]) => {
      calls.push(["select", ...args]);
      return query;
    }),
    eq: vi.fn((...args: unknown[]) => {
      calls.push(["eq", ...args]);
      return query;
    }),
    is: vi.fn((...args: unknown[]) => {
      calls.push(["is", ...args]);
      return query;
    }),
    ilike: vi.fn((...args: unknown[]) => {
      calls.push(["ilike", ...args]);
      return query;
    }),
    contains: vi.fn((...args: unknown[]) => {
      calls.push(["contains", ...args]);
      return query;
    }),
    or: vi.fn((...args: unknown[]) => {
      calls.push(["or", ...args]);
      return query;
    }),
    order: vi.fn((...args: unknown[]) => {
      calls.push(["order", ...args]);
      return query;
    }),
    limit: vi.fn((...args: unknown[]) => {
      calls.push(["limit", ...args]);
      return query;
    }),
    maybeSingle: vi.fn(async () => result),
    then: (resolve: (value: QueryResult) => void, reject: (reason?: unknown) => void) =>
      Promise.resolve(result).then(resolve, reject),
  };

  return query;
}

function createSupabaseMock(results: QueryResult[]) {
  const queries = results.map(createQuery);
  const pendingQueries = [...queries];
  const from = vi.fn(() => {
    const query = pendingQueries.shift();
    if (!query) throw new Error("Unexpected query");
    return query;
  });

  return { from, queries };
}

const productRow = {
  id: "product-1",
  shop_id: "shop-1",
  title: "Handwoven Basket",
  description: "A basket",
  price: 120,
  compare_at_price: 150,
  stock_qty: 4,
  images: ["basket.jpg"],
  tags: ["home"],
  shipping_options: [
    {
      key: "market_pickup",
      enabled: true,
      price: 0,
      market_name: "Saturday Market",
      market_location: "Cape Town",
      market_province: "Western Cape",
    },
  ],
  is_featured: true,
  created_at: "2026-05-01T10:00:00.000Z",
  shops: {
    id: "shop-1",
    name: "Artisan Shop",
    slug: "artisan-shop",
    logo_url: null,
    location: "Cape Town",
    is_active: true,
    is_offline: false,
  },
  categories: { id: "category-1", name: "Home", slug: "home" },
  subcategories: null,
  product_variants: [
    {
      id: "variant-2",
      product_id: "product-1",
      display_name: "Large",
      option_values: ["large"],
      price: 140,
      compare_at_price: null,
      stock_qty: 2,
      images: [],
      is_active: true,
      sort_order: 2,
    },
    {
      id: "variant-1",
      product_id: "product-1",
      display_name: "Small",
      option_values: ["small"],
      price: 120,
      compare_at_price: 150,
      stock_qty: 2,
      images: ["small.jpg"],
      is_active: true,
      sort_order: 1,
    },
    {
      id: "variant-inactive",
      product_id: "product-1",
      display_name: "Archived",
      option_values: [],
      price: 100,
      compare_at_price: null,
      stock_qty: 0,
      images: [],
      is_active: false,
      sort_order: 0,
    },
  ],
};

describe("marketplace catalog helpers", () => {
  beforeEach(() => {
    vi.mocked(createClient).mockReset();
  });

  it("filters public product queries and maps catalog rows safely", async () => {
    const supabase = createSupabaseMock([{ data: [productRow], error: null }]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    const products = await getMarketplaceProducts({
      query: "Basket",
      categoryId: "category-1",
      tag: "home",
      sort: "price_asc",
      limit: 12,
    });

    expect(products).toHaveLength(1);
    expect(products[0]).toMatchObject({
      id: "product-1",
      shopId: "shop-1",
      compareAtPrice: 150,
      shop: { id: "shop-1", slug: "artisan-shop", isOffline: false },
      category: { id: "category-1", slug: "home" },
      subcategory: null,
      shippingOptions: [
        {
          key: "market_pickup",
          marketName: "Saturday Market",
          marketLocation: "Cape Town",
          marketProvince: "Western Cape",
        },
      ],
    });
    expect(products[0]?.variants.map((variant) => variant.id)).toEqual([
      "variant-1",
      "variant-2",
    ]);

    const calls = supabase.queries[0].calls;
    expect(calls).toContainEqual(["eq", "is_published", true]);
    expect(calls).toContainEqual(["is", "archived_at", null]);
    expect(calls).toContainEqual(["eq", "shops.is_active", true]);
    expect(calls).toContainEqual(["eq", "category_id", "category-1"]);
    expect(calls).toContainEqual(["contains", "tags", ["home"]]);
    expect(calls).toContainEqual(["ilike", "title", "%Basket%"]);
    expect(calls).toContainEqual(["order", "price", { ascending: true }]);
    expect(calls).toContainEqual(["limit", 12]);
  });

  it("loads a shop by id or slug before fetching that shop's products", async () => {
    const shopRow = {
      id: "shop-1",
      name: "Artisan Shop",
      slug: "artisan-shop",
      bio: "Bio",
      brand_story: "Story",
      cover_image_url: "cover.jpg",
      logo_url: null,
      location: "Cape Town",
      shipping_options: [],
      is_offline: false,
      is_active: true,
      products: [{ count: 7 }],
    };
    const supabase = createSupabaseMock([
      { data: shopRow, error: null },
      { data: [productRow], error: null },
    ]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    const shop = await getMarketplaceShop("artisan-shop");

    expect(shop).toMatchObject({
      id: "shop-1",
      slug: "artisan-shop",
      productCount: 7,
      products: [{ id: "product-1" }],
    });
    expect(supabase.from).toHaveBeenNthCalledWith(1, "shops");
    expect(supabase.queries[0].calls).toContainEqual(["eq", "slug", "artisan-shop"]);
    expect(supabase.from).toHaveBeenNthCalledWith(2, "products");
    expect(supabase.queries[1].calls).toContainEqual(["eq", "shop_id", "shop-1"]);
    expect(supabase.queries[1].calls).toContainEqual(["limit", 48]);
  });
});
