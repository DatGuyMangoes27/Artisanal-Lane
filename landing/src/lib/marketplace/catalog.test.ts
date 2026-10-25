import { beforeEach, describe, expect, it, vi } from "vitest";

import { createClient } from "@/lib/supabase/server";

import {
  getFreshMarketplaceProductCount,
  getFreshMarketplaceProducts,
  getMarketplaceProducts,
  getMarketplaceProductsByIds,
  getMarketplaceShop,
  getMarketplaceShops,
} from "./catalog";

vi.mock("server-only", () => ({}));
vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(),
}));

type QueryResult = {
  data: unknown;
  error: Error | null;
  count?: number | null;
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
    in: vi.fn((...args: unknown[]) => {
      calls.push(["in", ...args]);
      return query;
    }),
    gt: vi.fn((...args: unknown[]) => {
      calls.push(["gt", ...args]);
      return query;
    }),
    gte: vi.fn((...args: unknown[]) => {
      calls.push(["gte", ...args]);
      return query;
    }),
    lt: vi.fn((...args: unknown[]) => {
      calls.push(["lt", ...args]);
      return query;
    }),
    lte: vi.fn((...args: unknown[]) => {
      calls.push(["lte", ...args]);
      return query;
    }),
    not: vi.fn((...args: unknown[]) => {
      calls.push(["not", ...args]);
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
    range: vi.fn((...args: unknown[]) => {
      calls.push(["range", ...args]);
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
    expect(calls).toContainEqual(["eq", "shops.is_publicly_listed", true]);
    expect(calls).toContainEqual([
      "or",
      "stock_qty.gt.0,fulfillment_mode.in.(made_to_order,stocked_with_mto)",
    ]);
    expect(calls).toContainEqual(["eq", "category_id", "category-1"]);
    expect(calls).toContainEqual(["contains", "tags", ["home"]]);
    // Search pre-filters by word stem, then ranks + pages in memory.
    expect(calls).toContainEqual([
      "or",
      "title.ilike.%basket%,description.ilike.%basket%,tags.ov.{basket}",
    ]);
    expect(calls).toContainEqual(["limit", 300]);
  });

  it("ranks search results by relevance and drops in-word substring matches", async () => {
    const row = (id: string, title: string, description: string, createdAt: string) => ({
      ...productRow,
      id,
      title,
      description,
      tags: [],
      categories: null,
      created_at: createdAt,
    });
    const supabase = createSupabaseMock([
      {
        data: [
          row("santa", "Santa tree hanger", "Hangs from strings", "2026-10-21T00:00:00.000Z"),
          row("hoops", "Sweet Panda Hoops", "Clay earrings", "2026-10-20T00:00:00.000Z"),
          row("ring", "Silver Stacking Ring", "Sterling", "2026-01-01T00:00:00.000Z"),
          row("band", "Moon band", "A ring for every day", "2026-02-01T00:00:00.000Z"),
        ],
        error: null,
      },
    ]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    const products = await getMarketplaceProducts({ query: "rings", limit: 1, offset: 1 });
    expect(products.map((product) => product.id)).toEqual(["band"]);
    expect(supabase.queries[0].calls).toContainEqual([
      "or",
      "title.ilike.%ring%,description.ilike.%ring%,tags.ov.{rings,ring}",
    ]);
  });

  it("returns nothing for a punctuation-only search without querying", async () => {
    const supabase = createSupabaseMock([{ data: [productRow], error: null }]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);
    expect(await getMarketplaceProducts({ query: "%,()" })).toEqual([]);
  });

  it("limits fresh products and their count to the last seven days", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-08-02T12:00:00.000Z"));

    try {
      const supabase = createSupabaseMock([
        { data: [productRow], error: null },
        { data: null, error: null, count: 1 },
      ]);
      vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

      await getFreshMarketplaceProducts(8);
      await getFreshMarketplaceProductCount();

      const cutoff = "2026-07-26T12:00:00.000Z";
      expect(supabase.queries[0].calls).toContainEqual(["gte", "created_at", cutoff]);
      expect(supabase.queries[0].calls).toContainEqual(["limit", 8]);
      expect(supabase.queries[1].calls).toContainEqual(["gte", "created_at", cutoff]);
    } finally {
      vi.useRealTimers();
    }
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
      productCount: 1,
      products: [{ id: "product-1" }],
    });
    expect(supabase.from).toHaveBeenNthCalledWith(1, "shops");
    expect(String(supabase.queries[0].select.mock.calls[0]?.[0])).not.toContain(
      "products(count)",
    );
    expect(supabase.queries[0].calls).toContainEqual(["eq", "slug", "artisan-shop"]);
    expect(supabase.from).toHaveBeenNthCalledWith(2, "products");
    expect(supabase.queries[1].calls).toContainEqual(["eq", "shop_id", "shop-1"]);
    expect(supabase.queries[1].calls).toContainEqual([
      "or",
      "stock_qty.gt.0,fulfillment_mode.in.(made_to_order,stocked_with_mto)",
    ]);
    expect(supabase.queries[1].calls).toContainEqual(["limit", 96]);
  });

  it("loads every public shop product across multiple response pages", async () => {
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
    };
    const firstPage = Array.from({ length: 96 }, (_, index) => ({
      ...productRow,
      id: `product-${index + 1}`,
    }));
    const secondPage = Array.from({ length: 5 }, (_, index) => ({
      ...productRow,
      id: `product-${index + 97}`,
    }));
    const supabase = createSupabaseMock([
      { data: shopRow, error: null },
      { data: firstPage, error: null },
      { data: secondPage, error: null },
    ]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    const shop = await getMarketplaceShop("artisan-shop");

    expect(shop?.products).toHaveLength(101);
    expect(shop?.productCount).toBe(101);
    expect(supabase.queries[1].calls).toContainEqual(["limit", 96]);
    expect(supabase.queries[2].calls).toContainEqual(["range", 96, 191]);
  });

  it("loads public products by id for guest cart hydration", async () => {
    const supabase = createSupabaseMock([{ data: [productRow], error: null }]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    const products = await getMarketplaceProductsByIds(["product-1", "product-2", "product-1"]);

    expect(products).toHaveLength(1);
    expect(supabase.queries[0].calls).toContainEqual(["in", "id", ["product-1", "product-2"]]);
    expect(supabase.queries[0].calls).toContainEqual(["eq", "is_published", true]);
    expect(supabase.queries[0].calls).toContainEqual(["is", "archived_at", null]);
    expect(supabase.queries[0].calls).toContainEqual(["eq", "shops.is_publicly_listed", true]);
    expect(supabase.queries[0].calls).toContainEqual([
      "or",
      "stock_qty.gt.0,fulfillment_mode.in.(made_to_order,stocked_with_mto)",
    ]);
  });

  it("can hydrate cart products that are reserved down to zero stock", async () => {
    const supabase = createSupabaseMock([{ data: [{ ...productRow, stock_qty: 0 }], error: null }]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    const products = await getMarketplaceProductsByIds(["product-1"], {
      includeOutOfStock: true,
    });

    expect(products).toHaveLength(1);
    expect(supabase.queries[0].calls).not.toContainEqual(["gt", "stock_qty", 0]);
  });

  it("applies mobile-style discovery filters for price, sale, and popularity", async () => {
    const supabase = createSupabaseMock([{ data: [productRow], error: null }]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    await getMarketplaceProducts({
      priceFilter: "under_200",
      availabilityFilter: "on_sale",
      sort: "popular",
    });

    const calls = supabase.queries[0].calls;
    expect(calls).toContainEqual(["lt", "price", 200]);
    expect(calls).toContainEqual(["not", "compare_at_price", "is", null]);
    expect(calls).toContainEqual(["order", "is_featured", { ascending: false }]);
    expect(calls).toContainEqual(["order", "created_at", { ascending: false }]);
  });

  it("uses range when loading an offset product page", async () => {
    const supabase = createSupabaseMock([{ data: [productRow], error: null }]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    await getMarketplaceProducts({ limit: 9, offset: 8 });

    expect(supabase.queries[0].calls).toContainEqual(["range", 8, 16]);
  });

  it("keeps the new-arrivals cutoff on later catalogue pages", async () => {
    const supabase = createSupabaseMock([{ data: [productRow], error: null }]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);
    await getMarketplaceProducts({ createdAfter: "2026-09-01T00:00:00.000Z", limit: 25, offset: 24, sort: "newest" });
    expect(supabase.queries[0].calls).toContainEqual(["gte", "created_at", "2026-09-01T00:00:00.000Z"]);
    expect(supabase.queries[0].calls).toContainEqual(["range", 24, 48]);
    expect(supabase.queries[0].calls).toContainEqual(["eq", "shops.is_publicly_listed", true]);
    expect(supabase.queries[0].calls).toContainEqual(["is", "archived_at", null]);
  });

  it("lists only publicly listed shops for the directory with cover and count", async () => {
    const shopRow = (id: string, name: string, cover: string | null) => ({
      id,
      vendor_id: null,
      name,
      slug: `${id}-slug`,
      bio: null,
      brand_story: null,
      logo_url: `https://cdn.example.com/${id}-logo.jpg`,
      cover_image_url: cover,
      location: "Durban",
      is_offline: false,
      is_spotlight: false,
      shipping_options: [],
      vendor: null,
    });
    const supabase = createSupabaseMock([
      {
        data: [
          shopRow("shop-b", "Blackreefforge", "https://cdn.example.com/cover.jpg"),
          shopRow("shop-a", "Amber Weaves", null),
        ],
        error: null,
      },
      {
        data: [
          { id: "p1", shop_id: "shop-b" },
          { id: "p2", shop_id: "shop-b" },
        ],
        error: null,
      },
    ]);
    vi.mocked(createClient).mockResolvedValue(supabase as unknown as SupabaseClientMock);

    const shops = await getMarketplaceShops(1000);

    expect(supabase.from).toHaveBeenNthCalledWith(1, "shops");
    expect(supabase.queries[0].calls).toContainEqual(["eq", "is_publicly_listed", true]);
    expect(supabase.queries[1].calls).toContainEqual(["eq", "shops.is_publicly_listed", true]);
    expect(shops.map((shop) => [shop.name, shop.coverImageUrl, shop.productCount])).toEqual([
      ["Amber Weaves", null, 0],
      ["Blackreefforge", "https://cdn.example.com/cover.jpg", 2],
    ]);
  });
});
