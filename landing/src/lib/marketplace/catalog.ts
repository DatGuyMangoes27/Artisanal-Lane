import "server-only";

import { createClient } from "@/lib/supabase/server";

import type {
  MarketplaceCategorySummary,
  MarketplaceProduct,
  MarketplaceShop,
  MarketplaceShopSummary,
  MarketplaceVariant,
  ShippingOption,
} from "./types";

export type MarketplaceProductSort = "newest" | "price_asc" | "price_desc";

export type MarketplaceProductOptions = {
  query?: string;
  categoryId?: string;
  tag?: string;
  sort?: MarketplaceProductSort;
  limit?: number;
};

type ProductQueryOptions = MarketplaceProductOptions & {
  shopId?: string;
};

const defaultProductLimit = 24;
const maxProductLimit = 96;
const defaultShopLimit = 24;
const maxShopLimit = 96;

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
  shipping_options,
  is_featured,
  created_at,
  shops!inner(id, name, slug, logo_url, location, is_active, is_offline),
  categories(id, name, slug),
  subcategories(id, name, slug),
  product_variants(id, product_id, display_name, option_values, price, compare_at_price, stock_qty, images, is_active, sort_order)
`;

const shopSelect = `
  id,
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
  products(count)
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
  bio: string | null;
  brand_story: string | null;
  cover_image_url: string | null;
  shipping_options: unknown;
  products?: Relation<{ count: number }>;
};

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
  shipping_options: unknown;
  is_featured: boolean;
  created_at: string;
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

  return value.map((option) => {
    const row = toRecord(option) ?? {};

    return {
      key: String(row.key ?? ""),
      enabled: row.enabled === true,
      price: toNumber(row.price),
      marketName: toStringOrNull(row.market_name ?? row.marketName),
      marketLocation: toStringOrNull(row.market_location ?? row.marketLocation),
      marketProvince: toStringOrNull(row.market_province ?? row.marketProvince),
    };
  });
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
    shippingOptions: mapShippingOptions(row.shipping_options),
    isFeatured: row.is_featured,
    createdAt: row.created_at,
    shop: mapShopSummary(row.shops),
    category: mapCategorySummary(row.categories),
    subcategory: mapCategorySummary(row.subcategories),
    variants: mapVariants(row.product_variants),
  };
}

function countProducts(row: Relation<{ count: number }>) {
  const countRow = firstRelation(row);
  return countRow?.count ?? 0;
}

function isUuid(value: string) {
  return uuidPattern.test(value);
}

function mapShop(row: ShopRow, products: MarketplaceProduct[] = []): MarketplaceShop {
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
    shippingOptions: mapShippingOptions(row.shipping_options),
    productCount: countProducts(row.products),
    products,
  };
}

async function loadProducts(options: ProductQueryOptions = {}) {
  const supabase = await createClient();
  let query = supabase
    .from("products")
    .select(productSelect)
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true);

  const searchQuery = options.query?.trim();
  if (searchQuery) {
    query = query.ilike("title", `%${searchQuery}%`);
  }

  if (options.categoryId) {
    query = query.eq("category_id", options.categoryId);
  }

  if (options.shopId) {
    query = query.eq("shop_id", options.shopId);
  }

  if (options.tag) {
    query = query.contains("tags", [options.tag]);
  }

  switch (options.sort) {
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

  const { data, error } = await query.limit(
    boundedLimit(options.limit, defaultProductLimit, maxProductLimit),
  );

  if (error) {
    throw new Error("Failed to load marketplace products", { cause: error });
  }

  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getMarketplaceProducts(options: MarketplaceProductOptions = {}) {
  return loadProducts(options);
}

export async function getFeaturedMarketplaceProducts(limit?: number) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("products")
    .select(productSelect)
    .eq("is_published", true)
    .is("archived_at", null)
    .eq("shops.is_active", true)
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
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load marketplace product", { cause: error });
  }

  return data ? mapProduct(data as ProductRow) : null;
}

export async function getMarketplaceProductsForShop(shopId: string, limit?: number) {
  return loadProducts({
    sort: "newest",
    limit: boundedLimit(limit, defaultProductLimit, maxProductLimit),
    shopId,
  });
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

export async function getMarketplaceShops(limit?: number) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("shops")
    .select(shopSelect)
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(boundedLimit(limit, defaultShopLimit, maxShopLimit));

  if (error) {
    throw new Error("Failed to load marketplace shops", { cause: error });
  }

  return ((data ?? []) as ShopRow[]).map((shop) => mapShop(shop));
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
  const products = await getMarketplaceProductsForShop(shop.id, 48);

  return mapShop(shop, products);
}
