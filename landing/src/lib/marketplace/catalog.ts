import "server-only";

import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

import type {
  FulfillmentMode,
  MarketplaceCategorySummary,
  MarketplaceOptionGroup,
  MarketplaceProduct,
  MarketplaceShop,
  MarketplaceShopSummary,
  MarketplaceVariant,
  ShippingOption,
} from "./types";
import { resolveTrendingSearchTerms } from "./search-trends";
import { isKnownShippingMethod } from "./shipping";

export type MarketplaceProductSort = "newest" | "price_asc" | "price_desc" | "popular";
export type MarketplacePriceFilter = "under_200" | "between_200_500" | "over_500";
export type MarketplaceAvailabilityFilter = "on_sale";

export type MarketplaceProductOptions = {
  query?: string;
  categoryId?: string;
  subcategoryId?: string;
  tag?: string;
  sort?: MarketplaceProductSort;
  priceFilter?: MarketplacePriceFilter;
  availabilityFilter?: MarketplaceAvailabilityFilter;
  limit?: number;
  offset?: number;
};

type ProductQueryOptions = MarketplaceProductOptions & {
  shopId?: string;
};

const defaultProductLimit = 24;
const maxProductLimit = 96;
const allProductsPageSize = maxProductLimit;
const defaultShopLimit = 24;
const maxShopLimit = 1000;

// A product is buyable when it has stock, or when it is made-to-order
// (which stays available even at zero inventory).
const availableProductFilter =
  "stock_qty.gt.0,fulfillment_mode.in.(made_to_order,stocked_with_mto)";

const productSelect = `
  id,
  shop_id,
  title,
  description,
  price,
  compare_at_price,
  stock_qty,
  images,
  tags,
  fragrance_description,
  shipping_options,
  is_featured,
  created_at,
  option_groups,
  fulfillment_mode,
  made_to_order_price,
  made_to_order_lead_min_days,
  made_to_order_lead_max_days,
  made_to_order_capacity,
  made_to_order_allow_custom_note,
  shops!inner(id, name, slug, logo_url, location, is_active, is_offline),
  categories(id, name, slug),
  subcategories(id, name, slug),
  product_variants(id, product_id, display_name, option_values, price, compare_at_price, stock_qty, images, is_active, sort_order)
`;

const shopSelect = `
  id,
  vendor_id,
  name,
  slug,
  bio,
  brand_story,
  cover_image_url,
  logo_url,
  location,
  shipping_options,
  is_active,
  is_offline,
  is_spotlight,
  vendor:profiles!shops_vendor_id_fkey(display_name, avatar_url)
`;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type Relation<T> = T | T[] | null | undefined;
type JsonRecord = Record<string, unknown>;

type CategoryRow = {
  id: string;
  name: string;
  slug: string | null;
};

type ShopSummaryRow = {
  id: string;
  name: string;
  slug: string;
  logo_url: string | null;
  location: string | null;
  is_active?: boolean;
  is_offline: boolean;
};

type ShopRow = ShopSummaryRow & {
  vendor_id: string | null;
  bio: string | null;
  brand_story: string | null;
  cover_image_url: string | null;
  shipping_options: unknown;
  is_spotlight: boolean | null;
  vendor: Relation<{ display_name: string | null; avatar_url: string | null }>;
};

type SupabaseServerClient = Awaited<ReturnType<typeof createClient>>;

type VariantRow = {
  id: string;
  product_id: string;
  display_name: string;
  option_values: unknown;
  price: number | string;
  compare_at_price: number | string | null;
  stock_qty: number | null;
  images: unknown;
  is_active: boolean;
  sort_order: number | null;
};

type ProductRow = {
  id: string;
  shop_id: string;
  title: string;
  description: string | null;
  price: number | string;
  compare_at_price: number | string | null;
  stock_qty: number | null;
  images: unknown;
  tags: unknown;
  fragrance_description: string | null;
  shipping_options: unknown;
  is_featured: boolean;
  created_at: string;
  option_groups: unknown;
  fulfillment_mode: string | null;
  made_to_order_price: number | string | null;
  made_to_order_lead_min_days: number | null;
  made_to_order_lead_max_days: number | null;
  made_to_order_capacity: number | null;
  made_to_order_allow_custom_note: boolean | null;
  shops: Relation<ShopSummaryRow>;
  categories: Relation<CategoryRow>;
  subcategories: Relation<CategoryRow>;
  product_variants: Relation<VariantRow>;
};

function boundedLimit(value: number | undefined, fallback: number, max: number) {
  if (value == null || !Number.isFinite(value)) {
    return fallback;
  }

  return Math.min(Math.max(Math.trunc(value), 1), max);
}

function toRecord(value: unknown): JsonRecord | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as JsonRecord;
}

function firstRelation<T>(value: Relation<T>): T | null {
  if (Array.isArray(value)) {
    return value[0] ?? null;
  }

  return value ?? null;
}

function toStringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function toNumber(value: unknown, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  return fallback;
}

function toStringArray(value: unknown) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.map((item) => String(item));
}

function mapShippingOptions(value: unknown): ShippingOption[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((option) => {
      const row = toRecord(option) ?? {};

      return {
        key: String(row.key ?? ""),
        // Mirror mobile parsing: a missing "enabled" flag means the method is on.
        enabled: row.enabled !== false,
        price: toNumber(row.price),
        marketName: toStringOrNull(row.market_name ?? row.marketName),
        marketLocation: toStringOrNull(row.market_location ?? row.marketLocation),
        marketProvince: toStringOrNull(row.market_province ?? row.marketProvince),
      };
    })
    .filter((option) => isKnownShippingMethod(option.key));
}

function mapCategorySummary(row: Relation<CategoryRow>): MarketplaceCategorySummary | null {
  const category = firstRelation(row);

  if (!category) {
    return null;
  }

  return {
    id: category.id,
    name: category.name,
    slug: category.slug,
  };
}

function mapShopSummary(row: Relation<ShopSummaryRow>): MarketplaceShopSummary | null {
  const shop = firstRelation(row);

  if (!shop) {
    return null;
  }

  return {
    id: shop.id,
    name: shop.name,
    slug: shop.slug,
    logoUrl: shop.logo_url,
    location: shop.location,
    isOffline: shop.is_offline,
  };
}

function mapVariant(row: VariantRow): MarketplaceVariant {
  return {
    id: row.id,
    productId: row.product_id,
    displayName: row.display_name,
    optionValues: toStringArray(row.option_values),
    price: toNumber(row.price),
    compareAtPrice: row.compare_at_price == null ? null : toNumber(row.compare_at_price),
    stockQty: row.stock_qty ?? 0,
    images: toStringArray(row.images),
    isActive: row.is_active,
    sortOrder: row.sort_order ?? 0,
  };
}

function mapVariants(row: Relation<VariantRow>): MarketplaceVariant[] {
  const variants = Array.isArray(row) ? row : row ? [row] : [];

  return variants
    .filter((variant) => variant.is_active)
    .map(mapVariant)
    .sort((a, b) => a.sortOrder - b.sortOrder);
}

function mapOptionGroups(value: unknown): MarketplaceOptionGroup[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((entry) => {
      const row = toRecord(entry) ?? {};
      const name = String(row.name ?? "").trim();
      const values = toStringArray(row.values).filter((item) => item.trim().length > 0);
      return { name, values };
    })
    .filter((group) => group.name.length > 0 && group.values.length > 0);
}

function normalizeFulfillmentMode(value: string | null): FulfillmentMode {
  return value === "made_to_order" || value === "stocked_with_mto" ? value : "stocked";
}

function mapProduct(row: ProductRow): MarketplaceProduct {
  return {
    id: row.id,
    shopId: row.shop_id,
    title: row.title,
    description: row.description,
    price: toNumber(row.price),
    compareAtPrice: row.compare_at_price == null ? null : toNumber(row.compare_at_price),
    stockQty: row.stock_qty ?? 0,
    images: toStringArray(row.images),
    tags: toStringArray(row.tags),
    fragranceDescription: row.fragrance_description,
    shippingOptions: mapShippingOptions(row.shipping_options),
    isFeatured: row.is_featured,
    createdAt: row.created_at,
    shop: mapShopSummary(row.shops),
    category: mapCategorySummary(row.categories),
    subcategory: mapCategorySummary(row.subcategories),
    variants: mapVariants(row.product_variants),
    optionGroups: mapOptionGroups(row.option_groups),
    fulfillmentMode: normalizeFulfillmentMode(row.fulfillment_mode),
    madeToOrderPrice:
      row.made_to_order_price == null ? null : toNumber(row.made_to_order_price),
    leadMinDays: row.made_to_order_lead_min_days,
    leadMaxDays: row.made_to_order_lead_max_days,
    madeToOrderCapacity: row.made_to_order_capacity,
    allowCustomNote: row.made_to_order_allow_custom_note === true,
  };
}

function isUuid(value: string) {
  return uuidPattern.test(value);
}

function mapShop(
  row: ShopRow,
  products: MarketplaceProduct[] = [],
  productCount = products.length,
): MarketplaceShop {
  const vendor = Array.isArray(row.vendor) ? row.vendor[0] : row.vendor;
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    logoUrl: row.logo_url,
    location: row.location,
    isOffline: row.is_offline,
    bio: row.bio,
    brandStory: row.brand_story,
    coverImageUrl: row.cover_image_url,
    artisanName: vendor?.display_name ?? null,
    artisanAvatarUrl: vendor?.avatar_url ?? null,
    shippingOptions: mapShippingOptions(row.shipping_options),
    productCount,
    products,
  };
}

async function loadPublicProductCountsForShops(
  supabase: SupabaseServerClient,
  shopIds: string[],
) {
  const uniqueShopIds = Array.from(new Set(shopIds.filter(Boolean)));

  if (uniqueShopIds.length === 0) {
    return new Map<string, number>();
  }

  const { data, error } = await supabase
    .from("products")
    .select("id, shop_id, shops!inner(id)")
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true)
    .or(availableProductFilter)
    .in("shop_id", uniqueShopIds);

  if (error) {
    throw new Error("Failed to load marketplace shop product counts", { cause: error });
  }

  const counts = new Map<string, number>();
  for (const product of (data ?? []) as Array<{ shop_id: string | null }>) {
    if (!product.shop_id) {
      continue;
    }

    counts.set(product.shop_id, (counts.get(product.shop_id) ?? 0) + 1);
  }

  return counts;
}

type VendorSubscriptionRow = {
  vendor_id: string;
  status: string;
  cancelled_at: string | null;
  current_period_end: string | null;
};

// Mirrors public.vendor_subscription_is_active: an "active" row, or a
// cancelled row that is still within its paid-through period.
function isSubscriptionActive(row: VendorSubscriptionRow, now: number) {
  const periodEnd = row.current_period_end
    ? Date.parse(row.current_period_end)
    : null;

  if (row.status === "active" && row.cancelled_at == null) {
    return periodEnd == null || periodEnd > now;
  }

  if (row.status === "cancelled") {
    return periodEnd != null && periodEnd > now;
  }

  return false;
}

// vendor_subscriptions is RLS-protected (vendor/admin only), so the public
// directory ranking reads it with the service-role client. Ranking is
// non-critical, so failures degrade to "nobody subscribed" instead of
// breaking the page.
async function loadSubscribedVendorIds(vendorIds: Array<string | null>) {
  const uniqueVendorIds = Array.from(
    new Set(vendorIds.filter((id): id is string => Boolean(id))),
  );

  if (uniqueVendorIds.length === 0) {
    return new Set<string>();
  }

  try {
    const admin = createAdminClient();
    const { data, error } = await admin
      .from("vendor_subscriptions")
      .select("vendor_id, status, cancelled_at, current_period_end")
      .in("vendor_id", uniqueVendorIds);

    if (error) {
      return new Set<string>();
    }

    const now = Date.now();
    return new Set(
      ((data ?? []) as VendorSubscriptionRow[])
        .filter((row) => isSubscriptionActive(row, now))
        .map((row) => row.vendor_id),
    );
  } catch {
    return new Set<string>();
  }
}

async function loadProducts(options: ProductQueryOptions = {}) {
  const supabase = await createClient();
  let query = supabase
    .from("products")
    .select(productSelect)
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true)
    .or(availableProductFilter);

  const searchQuery = options.query?.trim();
  if (searchQuery) {
    query = query.ilike("title", `%${searchQuery}%`);
  }

  if (options.categoryId) {
    query = query.eq("category_id", options.categoryId);

    // Subcategories only narrow within a category, mirroring the mobile app's
    // category screen filter.
    if (options.subcategoryId) {
      query = query.eq("subcategory_id", options.subcategoryId);
    }
  }

  if (options.shopId) {
    query = query.eq("shop_id", options.shopId);
  }

  if (options.tag) {
    query = query.contains("tags", [options.tag]);
  }

  switch (options.priceFilter) {
    case "under_200":
      query = query.lt("price", 200);
      break;
    case "between_200_500":
      query = query.gte("price", 200).lte("price", 500);
      break;
    case "over_500":
      query = query.gt("price", 500);
      break;
    default:
      break;
  }

  if (options.availabilityFilter === "on_sale") {
    query = query.not("compare_at_price", "is", null);
  }

  switch (options.sort) {
    case "popular":
      query = query.order("is_featured", { ascending: false });
      query = query.order("created_at", { ascending: false });
      break;
    case "price_asc":
      query = query.order("price", { ascending: true });
      break;
    case "price_desc":
      query = query.order("price", { ascending: false });
      break;
    case "newest":
    default:
      query = query.order("created_at", { ascending: false });
      break;
  }

  // Keep range-based pagination stable when multiple products share the same
  // primary sort value.
  query = query.order("id", { ascending: true });

  const limit = boundedLimit(options.limit, defaultProductLimit, maxProductLimit);
  const offset = Math.max(Math.trunc(options.offset ?? 0), 0);
  const { data, error } = offset > 0
    ? await query.range(offset, offset + limit - 1)
    : await query.limit(limit);

  if (error) {
    throw new Error("Failed to load marketplace products", { cause: error });
  }

  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getMarketplaceProducts(options: MarketplaceProductOptions = {}) {
  return loadProducts(options);
}

export async function getTrendingSearchTerms(limit = 8) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("trending_searches")
    .select("term")
    .eq("is_active", true)
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    return resolveTrendingSearchTerms({
      configuredTerms: [],
      fallbackTerms: ["Ceramics", "Candles", "Jewellery", "Textiles", "Baskets"],
      limit,
    });
  }

  return resolveTrendingSearchTerms({
    configuredTerms: (data ?? []).map((row: { term: string | null }) => row.term ?? ""),
    fallbackTerms: ["Ceramics", "Candles", "Jewellery", "Textiles", "Baskets"],
    limit,
  });
}

export async function getFeaturedMarketplaceProducts(limit?: number) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .select(productSelect)
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true)
    .or(availableProductFilter)
    .eq("is_featured", true)
    .order("created_at", { ascending: false })
    .limit(boundedLimit(limit, 8, maxProductLimit));

  if (error) {
    throw new Error("Failed to load featured marketplace products", { cause: error });
  }

  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getFreshMarketplaceProducts(limit?: number) {
  return loadProducts({ sort: "newest", limit: boundedLimit(limit, 12, maxProductLimit) });
}

export async function getMarketplaceProduct(productId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .select(productSelect)
    .eq("id", productId)
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true)
    .or(availableProductFilter)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load marketplace product", { cause: error });
  }

  return data ? mapProduct(data as ProductRow) : null;
}

export async function getMarketplaceProductsByIds(
  productIds: string[],
  options: { includeOutOfStock?: boolean } = {},
) {
  const ids = Array.from(new Set(productIds.filter(Boolean)));
  if (ids.length === 0) {
    return [];
  }

  const supabase = await createClient();
  let query = supabase
    .from("products")
    .select(productSelect)
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true);

  if (!options.includeOutOfStock) {
    query = query.or(availableProductFilter);
  }

  const { data, error } = await query.in("id", ids);
  if (error) {
    throw new Error("Failed to load marketplace cart products", { cause: error });
  }

  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getMarketplaceProductsForShop(shopId: string, limit?: number) {
  if (limit != null) {
    return loadProducts({
      sort: "newest",
      limit: boundedLimit(limit, defaultProductLimit, maxProductLimit),
      shopId,
    });
  }

  const products: MarketplaceProduct[] = [];
  let offset = 0;

  while (true) {
    const page = await loadProducts({
      sort: "newest",
      limit: allProductsPageSize,
      offset,
      shopId,
    });
    products.push(...page);

    if (page.length < allProductsPageSize) {
      return products;
    }

    offset += page.length;
  }
}

export async function getMarketplaceCategories() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("categories")
    .select("id, name, slug")
    .order("sort_order", { ascending: true });

  if (error) {
    throw new Error("Failed to load marketplace categories", { cause: error });
  }

  return ((data ?? []) as CategoryRow[]).map((category) => ({
    id: category.id,
    name: category.name,
    slug: category.slug,
  }));
}

export async function getMarketplaceSubcategories() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("subcategories")
    .select("id, category_id, name, slug")
    .order("sort_order", { ascending: true });

  if (error) {
    throw new Error("Failed to load marketplace subcategories", { cause: error });
  }

  return ((data ?? []) as Array<CategoryRow & { category_id: string | null }>).map(
    (subcategory) => ({
      id: subcategory.id,
      categoryId: subcategory.category_id,
      name: subcategory.name,
      slug: subcategory.slug,
    }),
  );
}

export async function getMarketplaceShops(limit?: number) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("shops")
    .select(shopSelect)
    .eq("is_active", true)
    .order("is_spotlight", { ascending: false })
    .order("name", { ascending: true })
    .limit(boundedLimit(limit, defaultShopLimit, maxShopLimit));

  if (error) {
    throw new Error("Failed to load marketplace shops", { cause: error });
  }

  const shops = (data ?? []) as ShopRow[];
  const [publicProductCounts, subscribedVendorIds] = await Promise.all([
    loadPublicProductCountsForShops(
      supabase,
      shops.map((shop) => shop.id),
    ),
    loadSubscribedVendorIds(shops.map((shop) => shop.vendor_id)),
  ]);

  // Tiered directory order: spotlighted shops, then shops with an active
  // subscription, then everyone else; alphabetical by name within each tier.
  const rankShop = (shop: ShopRow) => {
    if (shop.is_spotlight === true) {
      return 0;
    }

    if (shop.vendor_id && subscribedVendorIds.has(shop.vendor_id)) {
      return 1;
    }

    return 2;
  };

  return shops
    .slice()
    .sort((a, b) => rankShop(a) - rankShop(b) || a.name.localeCompare(b.name))
    .map((shop) => mapShop(shop, [], publicProductCounts.get(shop.id) ?? 0));
}

export async function getMarketplaceShopCount() {
  const supabase = await createClient();
  const { count, error } = await supabase
    .from("shops")
    .select("id", { count: "exact", head: true })
    .eq("is_active", true);

  if (error) {
    throw new Error("Failed to count marketplace shops", { cause: error });
  }

  return count ?? 0;
}

// Total number of products currently visible in the marketplace, mirroring the
// same visibility filters used by the product listings (published, not
// archived, active shop, and in-stock or made-to-order).
export async function getMarketplaceProductCount() {
  const supabase = await createClient();
  const { count, error } = await supabase
    .from("products")
    .select("id, shops!inner(id)", { count: "exact", head: true })
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true)
    .or(availableProductFilter);

  if (error) {
    throw new Error("Failed to count marketplace products", { cause: error });
  }

  return count ?? 0;
}

// Number of visible products added within the recent "fresh" window (default 30
// days), counted directly from the database.
export async function getFreshMarketplaceProductCount(days = 30) {
  const supabase = await createClient();
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
  const { count, error } = await supabase
    .from("products")
    .select("id, shops!inner(id)", { count: "exact", head: true })
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true)
    .or(availableProductFilter)
    .gte("created_at", since);

  if (error) {
    throw new Error("Failed to count fresh marketplace products", { cause: error });
  }

  return count ?? 0;
}

export async function getMarketplaceShop(shopIdOrSlug: string) {
  const supabase = await createClient();
  const lookupColumn = isUuid(shopIdOrSlug) ? "id" : "slug";
  const { data, error } = await supabase
    .from("shops")
    .select(shopSelect)
    .eq("is_active", true)
    .eq(lookupColumn, shopIdOrSlug)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load marketplace shop", { cause: error });
  }

  if (!data) {
    return null;
  }

  const shop = data as ShopRow;
  const products = await getMarketplaceProductsForShop(shop.id);

  return mapShop(shop, products);
}
