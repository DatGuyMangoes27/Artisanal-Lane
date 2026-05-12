# Web-Native Buyer Marketplace Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the web-native buyer marketplace foundation in `landing/`: public marketplace routes, Supabase catalog helpers, SEO product/shop pages, search/category discovery, and a guest cart foundation.

**Architecture:** Phase 1 adds buyer marketplace modules beside the existing admin code without touching the mobile Flutter app. Server components and server data helpers read public catalog data through the Supabase anon/server client, while client components handle interactive search controls and guest cart state in browser storage. Checkout, authenticated cart sync, orders, messages, disputes, and reviews are intentionally left for later phases.

**Tech Stack:** Next.js 16 App Router, React 19, TypeScript, Supabase SSR/browser clients, Tailwind CSS v4, shadcn-style UI components, Vitest for marketplace helper tests.

---

## Scope Boundary

This plan implements Phase 1 from `docs/superpowers/specs/2026-05-12-web-native-buyer-marketplace-design.md`.

Included:

- Public route structure for `/shop`, `/products/[id]`, and `/shops/[id]`.
- Public product/shop/category discovery.
- Product and shop card components.
- Product detail and shop profile pages.
- Search/filter query handling on `/shop`.
- Guest cart helper logic and a client cart drawer/link foundation.
- Test runner setup for TypeScript helper tests.

Not included:

- TradeSafe checkout.
- Authenticated cart sync.
- Favourites.
- Buyer account pages.
- Orders.
- Messages.
- Disputes.
- Review submission.
- Browser push notifications.

## File Map

- Modify: `landing/package.json` — add test scripts and Vitest dependencies.
- Create: `landing/vitest.config.ts` — Vitest configuration.
- Create: `landing/src/lib/marketplace/types.ts` — buyer marketplace TypeScript models.
- Create: `landing/src/lib/marketplace/format.ts` — price, date, image, and stock formatting helpers.
- Create: `landing/src/lib/marketplace/format.test.ts` — helper tests.
- Create: `landing/src/lib/marketplace/catalog.ts` — public Supabase catalog reads.
- Create: `landing/src/lib/marketplace/cart.ts` — guest cart types and pure cart helpers.
- Create: `landing/src/lib/marketplace/cart.test.ts` — guest cart tests.
- Create: `landing/src/components/marketplace/marketplace-header.tsx` — public marketplace navigation.
- Create: `landing/src/components/marketplace/product-card.tsx` — reusable product card.
- Create: `landing/src/components/marketplace/shop-card.tsx` — reusable shop card.
- Create: `landing/src/components/marketplace/search-controls.tsx` — client-side search/filter form.
- Create: `landing/src/components/marketplace/guest-cart-provider.tsx` — client storage provider for guest cart.
- Create: `landing/src/components/marketplace/add-to-cart-button.tsx` — client add-to-cart action.
- Create: `landing/src/app/shop/layout.tsx` — marketplace layout wrapper.
- Create: `landing/src/app/shop/page.tsx` — marketplace discovery page.
- Create: `landing/src/app/products/[productId]/page.tsx` — product detail page.
- Create: `landing/src/app/cart/page.tsx` — Phase 1 guest cart status page.
- Create: `landing/src/app/shops/[shopId]/page.tsx` — shop profile page.

## Task 1: Add Marketplace Test Harness

**Files:**

- Modify: `landing/package.json`
- Create: `landing/vitest.config.ts`

- [ ] **Step 1: Update `landing/package.json` test scripts and dev dependency plan**

Add `test` and `test:watch` scripts. Add the Vitest dependency with the package manager:

```powershell
npm install --save-dev vitest
```

Then ensure the `scripts` block contains:

```json
{
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "lint": "eslint",
  "test": "vitest run",
  "test:watch": "vitest"
}
```

- [ ] **Step 2: Create Vitest config**

Create `landing/vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
```

- [ ] **Step 3: Verify empty test harness**

Run from `landing/`:

```powershell
npm test
```

Expected: Vitest starts successfully. If it exits because no tests exist yet, continue to Task 2 and verify again after adding the first test file.

- [ ] **Step 4: Commit test harness**

```powershell
git add landing/package.json landing/package-lock.json landing/vitest.config.ts
git commit -m "test: add web marketplace test harness"
```

## Task 2: Add Marketplace Types And Formatting Helpers

**Files:**

- Create: `landing/src/lib/marketplace/types.ts`
- Create: `landing/src/lib/marketplace/format.ts`
- Create: `landing/src/lib/marketplace/format.test.ts`

- [ ] **Step 1: Write helper tests**

Create `landing/src/lib/marketplace/format.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "./format";
import type { MarketplaceProduct } from "./types";

const baseProduct: MarketplaceProduct = {
  id: "product-1",
  shopId: "shop-1",
  title: "Handwoven Basket",
  description: "A basket",
  price: 120,
  compareAtPrice: null,
  stockQty: 8,
  images: ["https://example.com/basket.jpg"],
  tags: [],
  shippingOptions: [],
  isFeatured: false,
  createdAt: "2026-05-01T10:00:00.000Z",
  shop: {
    id: "shop-1",
    name: "Artisan Shop",
    slug: "artisan-shop",
    logoUrl: null,
    location: "Cape Town",
    isOffline: false,
  },
  category: null,
  subcategory: null,
  variants: [],
};

describe("marketplace formatting", () => {
  it("formats prices in South African rand", () => {
    expect(formatPrice(120)).toBe("R120.00");
    expect(formatPrice(66.5)).toBe("R66.50");
  });

  it("detects sale products only when compare-at is higher", () => {
    expect(isProductOnSale({ ...baseProduct, compareAtPrice: 150 })).toBe(true);
    expect(isProductOnSale({ ...baseProduct, compareAtPrice: 120 })).toBe(false);
    expect(isProductOnSale({ ...baseProduct, compareAtPrice: null })).toBe(false);
  });

  it("uses the first product image or a safe fallback", () => {
    expect(getProductPrimaryImage(baseProduct)).toBe("https://example.com/basket.jpg");
    expect(getProductPrimaryImage({ ...baseProduct, images: [] })).toBe("/logo.png");
  });

  it("returns useful stock copy", () => {
    expect(getProductStockLabel({ ...baseProduct, stockQty: 0 })).toBe("Out of stock");
    expect(getProductStockLabel({ ...baseProduct, stockQty: 3 })).toBe("Only 3 left");
    expect(getProductStockLabel({ ...baseProduct, stockQty: 8 })).toBe("In stock");
  });
});
```

- [ ] **Step 2: Run tests to verify red**

Run from `landing/`:

```powershell
npm test -- src/lib/marketplace/format.test.ts
```

Expected: FAIL because `format.ts` and `types.ts` do not exist.

- [ ] **Step 3: Add marketplace types**

Create `landing/src/lib/marketplace/types.ts`:

```ts
export type ShippingOption = {
  key: string;
  enabled: boolean;
  price: number;
  marketName: string | null;
  marketLocation: string | null;
  marketProvince: string | null;
};

export type MarketplaceShopSummary = {
  id: string;
  name: string;
  slug: string;
  logoUrl: string | null;
  location: string | null;
  isOffline: boolean;
};

export type MarketplaceCategorySummary = {
  id: string;
  name: string;
  slug: string | null;
};

export type MarketplaceVariant = {
  id: string;
  productId: string;
  displayName: string;
  optionValues: string[];
  price: number;
  compareAtPrice: number | null;
  stockQty: number;
  images: string[];
  isActive: boolean;
  sortOrder: number;
};

export type MarketplaceProduct = {
  id: string;
  shopId: string;
  title: string;
  description: string | null;
  price: number;
  compareAtPrice: number | null;
  stockQty: number;
  images: string[];
  tags: string[];
  shippingOptions: ShippingOption[];
  isFeatured: boolean;
  createdAt: string;
  shop: MarketplaceShopSummary | null;
  category: MarketplaceCategorySummary | null;
  subcategory: MarketplaceCategorySummary | null;
  variants: MarketplaceVariant[];
};

export type MarketplaceShop = MarketplaceShopSummary & {
  bio: string | null;
  brandStory: string | null;
  coverImageUrl: string | null;
  shippingOptions: ShippingOption[];
  productCount: number;
  products: MarketplaceProduct[];
};
```

- [ ] **Step 4: Add formatting helpers**

Create `landing/src/lib/marketplace/format.ts`:

```ts
import type { MarketplaceProduct } from "./types";

export function formatPrice(value: number) {
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
    currencyDisplay: "narrowSymbol",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export function isProductOnSale(product: MarketplaceProduct) {
  return product.compareAtPrice != null && product.compareAtPrice > product.price;
}

export function getProductPrimaryImage(product: MarketplaceProduct) {
  return product.images[0] ?? "/logo.png";
}

export function getProductStockLabel(product: MarketplaceProduct) {
  if (product.stockQty <= 0) return "Out of stock";
  if (product.stockQty <= 5) return `Only ${product.stockQty} left`;
  return "In stock";
}
```

- [ ] **Step 5: Verify helper tests pass**

Run from `landing/`:

```powershell
npm test -- src/lib/marketplace/format.test.ts
```

Expected: PASS.

- [ ] **Step 6: Commit helper foundation**

```powershell
git add landing/src/lib/marketplace/types.ts landing/src/lib/marketplace/format.ts landing/src/lib/marketplace/format.test.ts
git commit -m "feat: add marketplace formatting helpers"
```

## Task 3: Add Public Catalog Data Helpers

**Files:**

- Create: `landing/src/lib/marketplace/catalog.ts`

- [ ] **Step 1: Create catalog mappers and queries**

Create `landing/src/lib/marketplace/catalog.ts`:

```ts
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

type ProductRow = Record<string, unknown> & {
  id: string;
  shop_id: string;
  title: string;
  description: string | null;
  price: number;
  compare_at_price: number | null;
  stock_qty: number | null;
  images: string[] | null;
  tags: string[] | null;
  shipping_options: Array<Record<string, unknown>> | null;
  is_featured: boolean | null;
  created_at: string;
  shops: Record<string, unknown> | null;
  categories: Record<string, unknown> | null;
  subcategories: Record<string, unknown> | null;
  product_variants: Array<Record<string, unknown>> | null;
};

type ShopRow = Record<string, unknown> & {
  id: string;
  name: string;
  slug: string;
  bio: string | null;
  brand_story: string | null;
  cover_image_url: string | null;
  logo_url: string | null;
  location: string | null;
  is_offline: boolean | null;
  shipping_options: Array<Record<string, unknown>> | null;
};

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map((entry) => String(entry)) : [];
}

function mapShippingOptions(value: Array<Record<string, unknown>> | null): ShippingOption[] {
  if (!Array.isArray(value)) return [];

  return value
    .map((option) => ({
      key: String(option.key ?? ""),
      enabled: option.enabled !== false,
      price: Number(option.price ?? 0),
      marketName: typeof option.market_name === "string" ? option.market_name : null,
      marketLocation:
        typeof option.market_location === "string" ? option.market_location : null,
      marketProvince:
        typeof option.market_province === "string" ? option.market_province : null,
    }))
    .filter((option) => option.key.length > 0);
}

function mapSummary(row: Record<string, unknown> | null): MarketplaceCategorySummary | null {
  if (!row) return null;
  return {
    id: String(row.id),
    name: String(row.name),
    slug: typeof row.slug === "string" ? row.slug : null,
  };
}

function mapShopSummary(row: Record<string, unknown> | null): MarketplaceShopSummary | null {
  if (!row) return null;
  return {
    id: String(row.id),
    name: String(row.name),
    slug: String(row.slug),
    logoUrl: typeof row.logo_url === "string" ? row.logo_url : null,
    location: typeof row.location === "string" ? row.location : null,
    isOffline: row.is_offline === true,
  };
}

function mapVariant(row: Record<string, unknown>): MarketplaceVariant {
  return {
    id: String(row.id),
    productId: String(row.product_id),
    displayName: typeof row.display_name === "string" ? row.display_name : "",
    optionValues: asStringArray(row.option_values),
    price: Number(row.price ?? 0),
    compareAtPrice: row.compare_at_price == null ? null : Number(row.compare_at_price),
    stockQty: Number(row.stock_qty ?? 0),
    images: asStringArray(row.images),
    isActive: row.is_active !== false,
    sortOrder: Number(row.sort_order ?? 0),
  };
}

function mapProduct(row: ProductRow): MarketplaceProduct {
  return {
    id: row.id,
    shopId: row.shop_id,
    title: row.title,
    description: row.description,
    price: Number(row.price),
    compareAtPrice: row.compare_at_price == null ? null : Number(row.compare_at_price),
    stockQty: Number(row.stock_qty ?? 0),
    images: asStringArray(row.images),
    tags: asStringArray(row.tags),
    shippingOptions: mapShippingOptions(row.shipping_options),
    isFeatured: row.is_featured === true,
    createdAt: row.created_at,
    shop: mapShopSummary(row.shops),
    category: mapSummary(row.categories),
    subcategory: mapSummary(row.subcategories),
    variants: (row.product_variants ?? [])
      .map(mapVariant)
      .filter((variant) => variant.isActive)
      .sort((a, b) => a.sortOrder - b.sortOrder),
  };
}

function publicProductQuery() {
  return createClient().then((supabase) =>
    supabase
      .from("products")
      .select(productSelect)
      .eq("is_published", true)
      .filter("archived_at", "is", null)
      .eq("shops.is_active", true),
  );
}

export async function getMarketplaceProducts(options: {
  query?: string;
  categoryId?: string;
  tag?: string;
  sort?: "newest" | "price_asc" | "price_desc";
  limit?: number;
} = {}) {
  let query = await publicProductQuery();

  if (options.query?.trim()) {
    query = query.ilike("title", `%${options.query.trim()}%`);
  }
  if (options.categoryId) {
    query = query.eq("category_id", options.categoryId);
  }
  if (options.tag) {
    query = query.contains("tags", [options.tag]);
  }

  const sort = options.sort ?? "newest";
  if (sort === "price_asc") query = query.order("price", { ascending: true });
  if (sort === "price_desc") query = query.order("price", { ascending: false });
  if (sort === "newest") query = query.order("created_at", { ascending: false });

  const { data, error } = await query.limit(options.limit ?? 48);
  if (error) throw error;
  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getFeaturedMarketplaceProducts(limit = 8) {
  const query = await publicProductQuery();
  const { data, error } = await query
    .eq("is_featured", true)
    .order("featured_at", { ascending: false, nullsFirst: false })
    .limit(limit);
  if (error) throw error;
  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getFreshMarketplaceProducts(limit = 8) {
  const query = await publicProductQuery();
  const { data, error } = await query.order("created_at", { ascending: false }).limit(limit);
  if (error) throw error;
  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getMarketplaceProduct(productId: string) {
  const query = await publicProductQuery();
  const { data, error } = await query.eq("id", productId).maybeSingle();
  if (error) throw error;
  return data ? mapProduct(data as ProductRow) : null;
}

export async function getMarketplaceProductsForShop(shopId: string, limit = 48) {
  const query = await publicProductQuery();
  const { data, error } = await query
    .eq("shop_id", shopId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return ((data ?? []) as ProductRow[]).map(mapProduct);
}

export async function getMarketplaceCategories() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("categories")
    .select("id, name, slug")
    .order("sort_order", { ascending: true });
  if (error) throw error;
  return (data ?? []).map((row) => ({
    id: String(row.id),
    name: String(row.name),
    slug: typeof row.slug === "string" ? row.slug : null,
  }));
}

export async function getMarketplaceShops(limit = 24) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("shops")
    .select("id, name, slug, logo_url, location, is_offline")
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(limit);
  if (error) throw error;
  return (data ?? []).map((row) => mapShopSummary(row)!).filter(Boolean);
}

export async function getMarketplaceShop(shopIdOrSlug: string): Promise<MarketplaceShop | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("shops")
    .select(
      "id, name, slug, bio, brand_story, cover_image_url, logo_url, location, is_offline, shipping_options",
    )
    .eq("is_active", true)
    .or(`id.eq.${shopIdOrSlug},slug.eq.${shopIdOrSlug}`)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;

  const shop = data as ShopRow;
  const shopProducts = await getMarketplaceProductsForShop(shop.id, 48);

  return {
    id: shop.id,
    name: shop.name,
    slug: shop.slug,
    logoUrl: shop.logo_url,
    location: shop.location,
    isOffline: shop.is_offline === true,
    bio: shop.bio,
    brandStory: shop.brand_story,
    coverImageUrl: shop.cover_image_url,
    shippingOptions: mapShippingOptions(shop.shipping_options),
    productCount: shopProducts.length,
    products: shopProducts,
  };
}
```

- [ ] **Step 2: Verify TypeScript compile through lint**

Run from `landing/`:

```powershell
npm run lint
```

Expected: no lint errors from `catalog.ts`.

- [ ] **Step 3: Commit catalog helpers**

```powershell
git add landing/src/lib/marketplace/catalog.ts
git commit -m "feat: add public marketplace catalog helpers"
```

## Task 4: Add Guest Cart Pure Helpers

**Files:**

- Create: `landing/src/lib/marketplace/cart.ts`
- Create: `landing/src/lib/marketplace/cart.test.ts`

- [ ] **Step 1: Write guest cart tests**

Create `landing/src/lib/marketplace/cart.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import {
  addGuestCartItem,
  getGuestCartItemKey,
  getGuestCartQuantity,
  removeGuestCartItem,
  updateGuestCartQuantity,
} from "./cart";

describe("guest cart helpers", () => {
  it("uses product and variant ids as a stable cart key", () => {
    expect(getGuestCartItemKey("product-1", null)).toBe("product-1");
    expect(getGuestCartItemKey("product-1", "variant-1")).toBe("product-1:variant-1");
  });

  it("adds and increments cart quantities", () => {
    const first = addGuestCartItem([], {
      productId: "product-1",
      variantId: null,
      quantity: 1,
    });
    const second = addGuestCartItem(first, {
      productId: "product-1",
      variantId: null,
      quantity: 2,
    });

    expect(second).toEqual([
      {
        key: "product-1",
        productId: "product-1",
        variantId: null,
        quantity: 3,
      },
    ]);
  });

  it("updates, removes, and sums quantities", () => {
    const cart = [
      { key: "product-1", productId: "product-1", variantId: null, quantity: 3 },
      { key: "product-2:v1", productId: "product-2", variantId: "v1", quantity: 2 },
    ];

    expect(getGuestCartQuantity(cart)).toBe(5);
    expect(updateGuestCartQuantity(cart, "product-1", 1)[0].quantity).toBe(1);
    expect(updateGuestCartQuantity(cart, "product-1", 0)).toHaveLength(1);
    expect(removeGuestCartItem(cart, "product-2:v1")).toHaveLength(1);
  });
});
```

- [ ] **Step 2: Run tests to verify red**

Run from `landing/`:

```powershell
npm test -- src/lib/marketplace/cart.test.ts
```

Expected: FAIL because `cart.ts` does not exist.

- [ ] **Step 3: Add cart helpers**

Create `landing/src/lib/marketplace/cart.ts`:

```ts
export type GuestCartItem = {
  key: string;
  productId: string;
  variantId: string | null;
  quantity: number;
};

export type GuestCartItemInput = {
  productId: string;
  variantId: string | null;
  quantity?: number;
};

export function getGuestCartItemKey(productId: string, variantId: string | null) {
  return variantId ? `${productId}:${variantId}` : productId;
}

export function addGuestCartItem(
  items: GuestCartItem[],
  input: GuestCartItemInput,
): GuestCartItem[] {
  const quantity = Math.max(1, input.quantity ?? 1);
  const key = getGuestCartItemKey(input.productId, input.variantId);
  const existing = items.find((item) => item.key === key);

  if (!existing) {
    return [
      ...items,
      {
        key,
        productId: input.productId,
        variantId: input.variantId,
        quantity,
      },
    ];
  }

  return items.map((item) =>
    item.key === key ? { ...item, quantity: item.quantity + quantity } : item,
  );
}

export function updateGuestCartQuantity(
  items: GuestCartItem[],
  key: string,
  quantity: number,
) {
  if (quantity <= 0) return removeGuestCartItem(items, key);
  return items.map((item) => (item.key === key ? { ...item, quantity } : item));
}

export function removeGuestCartItem(items: GuestCartItem[], key: string) {
  return items.filter((item) => item.key !== key);
}

export function getGuestCartQuantity(items: GuestCartItem[]) {
  return items.reduce((total, item) => total + item.quantity, 0);
}
```

- [ ] **Step 4: Verify cart tests pass**

Run from `landing/`:

```powershell
npm test -- src/lib/marketplace/cart.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit guest cart helpers**

```powershell
git add landing/src/lib/marketplace/cart.ts landing/src/lib/marketplace/cart.test.ts
git commit -m "feat: add guest cart helpers"
```

## Task 5: Add Marketplace Shell Components

**Files:**

- Create: `landing/src/components/marketplace/marketplace-header.tsx`
- Create: `landing/src/components/marketplace/product-card.tsx`
- Create: `landing/src/components/marketplace/shop-card.tsx`

- [ ] **Step 1: Create marketplace header**

Create `landing/src/components/marketplace/marketplace-header.tsx`:

```tsx
import Image from "next/image";
import Link from "next/link";
import { Search, ShoppingBag } from "lucide-react";

import { Button } from "@/components/ui/button";

export function MarketplaceHeader() {
  return (
    <header className="sticky top-0 z-40 border-b border-artisan-clay/70 bg-background/90 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <Link href="/shop" className="flex items-center gap-3">
          <Image src="/logo.png" alt="Artisan Lane" width={36} height={36} className="rounded-lg" />
          <span className="font-serif text-xl font-bold text-foreground">Artisan Lane</span>
        </Link>
        <nav className="hidden items-center gap-6 text-sm font-medium text-muted-foreground md:flex">
          <Link href="/shop" className="transition hover:text-foreground">Shop</Link>
          <Link href="/shop?sort=newest" className="transition hover:text-foreground">Fresh arrivals</Link>
          <Link href="/shop#artisans" className="transition hover:text-foreground">Artisans</Link>
        </nav>
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="icon" aria-label="Search">
            <Link href="/shop#search"><Search /></Link>
          </Button>
          <Button asChild variant="ghost" size="icon" aria-label="Cart">
            <Link href="/cart"><ShoppingBag /></Link>
          </Button>
        </div>
      </div>
    </header>
  );
}
```

- [ ] **Step 2: Create product card**

Create `landing/src/components/marketplace/product-card.tsx`:

```tsx
import Image from "next/image";
import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "@/lib/marketplace/format";
import type { MarketplaceProduct } from "@/lib/marketplace/types";

export function ProductCard({ product }: { product: MarketplaceProduct }) {
  const onSale = isProductOnSale(product);

  return (
    <Card className="overflow-hidden border-artisan-clay/80 bg-card/95 py-0">
      <Link href={`/products/${product.id}`} className="group block">
        <div className="relative aspect-square overflow-hidden bg-secondary">
          <Image
            src={getProductPrimaryImage(product)}
            alt={product.title}
            fill
            sizes="(min-width: 1024px) 25vw, (min-width: 640px) 50vw, 100vw"
            className="object-cover transition duration-500 group-hover:scale-105"
          />
          {onSale ? <Badge className="absolute left-3 top-3 bg-artisan-terracotta">Sale</Badge> : null}
        </div>
      </Link>
      <CardContent className="space-y-3 p-4">
        <div>
          <Link href={`/products/${product.id}`} className="font-semibold text-foreground hover:underline">
            {product.title}
          </Link>
          <p className="mt-1 text-sm text-muted-foreground">{product.shop?.name ?? "Artisan Lane seller"}</p>
        </div>
        <div className="flex items-end justify-between gap-3">
          <div>
            <p className="font-semibold text-foreground">{formatPrice(product.price)}</p>
            {onSale && product.compareAtPrice ? (
              <p className="text-sm text-muted-foreground line-through">{formatPrice(product.compareAtPrice)}</p>
            ) : null}
          </div>
          <span className="text-xs font-medium text-muted-foreground">{getProductStockLabel(product)}</span>
        </div>
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 3: Create shop card**

Create `landing/src/components/marketplace/shop-card.tsx`:

```tsx
import Image from "next/image";
import Link from "next/link";

import { Card, CardContent } from "@/components/ui/card";
import type { MarketplaceShopSummary } from "@/lib/marketplace/types";

export function ShopCard({ shop }: { shop: MarketplaceShopSummary }) {
  return (
    <Card className="border-artisan-clay/80 bg-card/95">
      <CardContent className="flex items-center gap-4 p-4">
        <div className="relative size-14 overflow-hidden rounded-full bg-secondary">
          <Image
            src={shop.logoUrl ?? "/logo.png"}
            alt={shop.name}
            fill
            sizes="56px"
            className="object-cover"
          />
        </div>
        <div className="min-w-0 flex-1">
          <Link href={`/shops/${shop.slug || shop.id}`} className="font-semibold hover:underline">
            {shop.name}
          </Link>
          <p className="truncate text-sm text-muted-foreground">{shop.location ?? "South Africa"}</p>
        </div>
      </CardContent>
    </Card>
  );
}
```

- [ ] **Step 4: Run lint**

Run from `landing/`:

```powershell
npm run lint
```

Expected: no lint errors.

- [ ] **Step 5: Commit marketplace components**

```powershell
git add landing/src/components/marketplace/marketplace-header.tsx landing/src/components/marketplace/product-card.tsx landing/src/components/marketplace/shop-card.tsx
git commit -m "feat: add marketplace shell components"
```

## Task 6: Build Public Marketplace Page

**Files:**

- Create: `landing/src/components/marketplace/search-controls.tsx`
- Create: `landing/src/app/shop/layout.tsx`
- Create: `landing/src/app/shop/page.tsx`

- [ ] **Step 1: Create search controls**

Create `landing/src/components/marketplace/search-controls.tsx`:

```tsx
"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useState } from "react";

import { Button } from "@/components/ui/button";
import type { MarketplaceCategorySummary } from "@/lib/marketplace/types";

export function SearchControls({ categories }: { categories: MarketplaceCategorySummary[] }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(searchParams.get("q") ?? "");
  const [categoryId, setCategoryId] = useState(searchParams.get("category") ?? "");
  const [sort, setSort] = useState(searchParams.get("sort") ?? "newest");

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const params = new URLSearchParams();
    if (query.trim()) params.set("q", query.trim());
    if (categoryId) params.set("category", categoryId);
    if (sort !== "newest") params.set("sort", sort);
    router.push(`/shop${params.size ? `?${params.toString()}` : ""}`);
  }

  return (
    <form id="search" onSubmit={onSubmit} className="grid gap-3 rounded-3xl border border-artisan-clay bg-card p-4 shadow-sm md:grid-cols-[1fr_220px_180px_auto]">
      <input
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search handmade products"
        className="h-11 rounded-full border border-input bg-background px-4 text-sm outline-none focus:ring-2 focus:ring-ring/30"
      />
      <select
        value={categoryId}
        onChange={(event) => setCategoryId(event.target.value)}
        className="h-11 rounded-full border border-input bg-background px-4 text-sm"
      >
        <option value="">All categories</option>
        {categories.map((category) => (
          <option key={category.id} value={category.id}>{category.name}</option>
        ))}
      </select>
      <select
        value={sort}
        onChange={(event) => setSort(event.target.value)}
        className="h-11 rounded-full border border-input bg-background px-4 text-sm"
      >
        <option value="newest">Newest</option>
        <option value="price_asc">Price: low to high</option>
        <option value="price_desc">Price: high to low</option>
      </select>
      <Button type="submit" className="h-11 rounded-full">Search</Button>
    </form>
  );
}
```

- [ ] **Step 2: Add marketplace layout**

Create `landing/src/app/shop/layout.tsx`:

```tsx
import type { ReactNode } from "react";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export default function ShopLayout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      {children}
    </div>
  );
}
```

- [ ] **Step 3: Add marketplace page**

Create `landing/src/app/shop/page.tsx`:

```tsx
import Link from "next/link";

import { ProductCard } from "@/components/marketplace/product-card";
import { SearchControls } from "@/components/marketplace/search-controls";
import { ShopCard } from "@/components/marketplace/shop-card";
import {
  getFeaturedMarketplaceProducts,
  getFreshMarketplaceProducts,
  getMarketplaceCategories,
  getMarketplaceProducts,
  getMarketplaceShops,
} from "@/lib/marketplace/catalog";

type ShopPageProps = {
  searchParams?: Promise<{
    q?: string;
    category?: string;
    sort?: "newest" | "price_asc" | "price_desc";
  }>;
};

export default async function ShopPage({ searchParams }: ShopPageProps) {
  const params = await searchParams;
  const [categories, products, featured, fresh, shops] = await Promise.all([
    getMarketplaceCategories(),
    getMarketplaceProducts({
      query: params?.q,
      categoryId: params?.category,
      sort: params?.sort,
    }),
    getFeaturedMarketplaceProducts(),
    getFreshMarketplaceProducts(),
    getMarketplaceShops(6),
  ]);

  return (
    <main>
      <section className="bg-gradient-to-br from-artisan-bone via-background to-artisan-clay/50">
        <div className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
          <div className="max-w-3xl">
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-artisan-terracotta">
              Artisan marketplace
            </p>
            <h1 className="mt-4 text-4xl font-bold text-foreground md:text-6xl">
              Discover handmade South African goods.
            </h1>
            <p className="mt-5 text-lg text-muted-foreground">
              Browse fresh arrivals, local artisans, and one-of-a-kind pieces from the same marketplace as the app.
            </p>
          </div>
          <div className="mt-8">
            <SearchControls categories={categories} />
          </div>
        </div>
      </section>

      <section id="artisans" className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="mb-6 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-2xl font-bold">Shop products</h2>
            <p className="text-muted-foreground">{products.length} products available</p>
          </div>
        </div>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {products.map((product) => <ProductCard key={product.id} product={product} />)}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="mb-6">
          <h2 className="text-2xl font-bold">Featured finds</h2>
          <p className="text-muted-foreground">Curated pieces from Artisan Lane sellers.</p>
        </div>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {featured.map((product) => <ProductCard key={product.id} product={product} />)}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="mb-6">
          <h2 className="text-2xl font-bold">Fresh arrivals</h2>
          <p className="text-muted-foreground">The newest published products from active shops.</p>
        </div>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {fresh.map((product) => <ProductCard key={product.id} product={product} />)}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="mb-6 flex items-end justify-between">
          <div>
            <h2 className="text-2xl font-bold">Meet the artisans</h2>
            <p className="text-muted-foreground">Explore active shops from the marketplace.</p>
          </div>
          <Link href="/shop?sort=newest" className="text-sm font-semibold text-artisan-terracotta">
            Browse all
          </Link>
        </div>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {shops.map((shop) => <ShopCard key={shop.id} shop={shop} />)}
        </div>
      </section>
    </main>
  );
}
```

- [ ] **Step 4: Verify route build**

Run from `landing/`:

```powershell
npm run lint
npm run build
```

Expected: both commands pass.

- [ ] **Step 5: Commit public marketplace page**

```powershell
git add landing/src/components/marketplace/search-controls.tsx landing/src/app/shop/layout.tsx landing/src/app/shop/page.tsx
git commit -m "feat: add public marketplace page"
```

## Task 7: Build Product Detail Page And Add-To-Cart Foundation

**Files:**

- Create: `landing/src/components/marketplace/guest-cart-provider.tsx`
- Create: `landing/src/components/marketplace/add-to-cart-button.tsx`
- Create: `landing/src/app/products/[productId]/page.tsx`
- Create: `landing/src/app/cart/page.tsx`

- [ ] **Step 1: Create guest cart provider**

Create `landing/src/components/marketplace/guest-cart-provider.tsx`:

```tsx
"use client";

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import {
  addGuestCartItem,
  getGuestCartQuantity,
  type GuestCartItem,
  type GuestCartItemInput,
} from "@/lib/marketplace/cart";

const storageKey = "artisan-lane-guest-cart";

type GuestCartContextValue = {
  items: GuestCartItem[];
  quantity: number;
  addItem: (item: GuestCartItemInput) => void;
};

const GuestCartContext = createContext<GuestCartContextValue | null>(null);

export function GuestCartProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<GuestCartItem[]>([]);

  useEffect(() => {
    const raw = window.localStorage.getItem(storageKey);
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw) as GuestCartItem[];
      if (Array.isArray(parsed)) setItems(parsed);
    } catch {
      window.localStorage.removeItem(storageKey);
    }
  }, []);

  useEffect(() => {
    window.localStorage.setItem(storageKey, JSON.stringify(items));
  }, [items]);

  const value = useMemo<GuestCartContextValue>(
    () => ({
      items,
      quantity: getGuestCartQuantity(items),
      addItem: (item) => setItems((current) => addGuestCartItem(current, item)),
    }),
    [items],
  );

  return <GuestCartContext.Provider value={value}>{children}</GuestCartContext.Provider>;
}

export function useGuestCart() {
  const context = useContext(GuestCartContext);
  if (!context) throw new Error("useGuestCart must be used inside GuestCartProvider");
  return context;
}
```

- [ ] **Step 2: Wrap marketplace layout in provider**

Modify `landing/src/app/shop/layout.tsx`:

```tsx
import type { ReactNode } from "react";

import { GuestCartProvider } from "@/components/marketplace/guest-cart-provider";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export default function ShopLayout({ children }: { children: ReactNode }) {
  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-background">
        <MarketplaceHeader />
        {children}
      </div>
    </GuestCartProvider>
  );
}
```

- [ ] **Step 3: Create add-to-cart button**

Create `landing/src/components/marketplace/add-to-cart-button.tsx`:

```tsx
"use client";

import { ShoppingBag } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { useGuestCart } from "@/components/marketplace/guest-cart-provider";

export function AddToCartButton({
  productId,
  variantId = null,
  disabled = false,
}: {
  productId: string;
  variantId?: string | null;
  disabled?: boolean;
}) {
  const { addItem } = useGuestCart();
  const [added, setAdded] = useState(false);

  return (
    <Button
      disabled={disabled}
      className="w-full rounded-full"
      onClick={() => {
        addItem({ productId, variantId, quantity: 1 });
        setAdded(true);
        window.setTimeout(() => setAdded(false), 1800);
      }}
    >
      <ShoppingBag />
      {added ? "Added to cart" : "Add to cart"}
    </Button>
  );
}
```

- [ ] **Step 4: Add product detail page**

Create `landing/src/app/products/[productId]/page.tsx`:

```tsx
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { AddToCartButton } from "@/components/marketplace/add-to-cart-button";
import { GuestCartProvider } from "@/components/marketplace/guest-cart-provider";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "@/lib/marketplace/format";
import { getMarketplaceProduct } from "@/lib/marketplace/catalog";

type ProductPageProps = {
  params: Promise<{ productId: string }>;
};

export async function generateMetadata({ params }: ProductPageProps) {
  const { productId } = await params;
  const product = await getMarketplaceProduct(productId);
  if (!product) return { title: "Product not found | Artisan Lane" };
  return {
    title: `${product.title} | Artisan Lane`,
    description: product.description ?? `Shop ${product.title} on Artisan Lane.`,
  };
}

export default async function ProductPage({ params }: ProductPageProps) {
  const { productId } = await params;
  const product = await getMarketplaceProduct(productId);
  if (!product) notFound();

  const onSale = isProductOnSale(product);
  const primaryImage = getProductPrimaryImage(product);

  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-background">
        <MarketplaceHeader />
        <main className="mx-auto grid max-w-7xl gap-10 px-4 py-10 sm:px-6 lg:grid-cols-[1.1fr_0.9fr] lg:px-8">
          <section className="space-y-4">
            <div className="relative aspect-square overflow-hidden rounded-3xl bg-secondary">
              <Image src={primaryImage} alt={product.title} fill priority sizes="(min-width: 1024px) 55vw, 100vw" className="object-cover" />
            </div>
            {product.images.length > 1 ? (
              <div className="grid grid-cols-4 gap-3">
                {product.images.slice(1, 5).map((image) => (
                  <div key={image} className="relative aspect-square overflow-hidden rounded-2xl bg-secondary">
                    <Image src={image} alt={product.title} fill sizes="160px" className="object-cover" />
                  </div>
                ))}
              </div>
            ) : null}
          </section>

          <section className="space-y-6">
            <div>
              {onSale ? <Badge className="mb-4 bg-artisan-terracotta">On sale</Badge> : null}
              <h1 className="text-4xl font-bold">{product.title}</h1>
              <p className="mt-3 text-muted-foreground">
                by{" "}
                {product.shop ? (
                  <Link href={`/shops/${product.shop.slug || product.shop.id}`} className="font-semibold text-foreground hover:underline">
                    {product.shop.name}
                  </Link>
                ) : (
                  "Artisan Lane seller"
                )}
              </p>
            </div>

            <div>
              <p className="text-3xl font-bold">{formatPrice(product.price)}</p>
              {onSale && product.compareAtPrice ? (
                <p className="text-muted-foreground line-through">{formatPrice(product.compareAtPrice)}</p>
              ) : null}
            </div>

            <p className="text-sm font-medium text-muted-foreground">{getProductStockLabel(product)}</p>

            {product.description ? (
              <div className="rounded-3xl border border-artisan-clay bg-card p-5">
                <h2 className="font-semibold">About this piece</h2>
                <p className="mt-2 whitespace-pre-line text-sm leading-6 text-muted-foreground">{product.description}</p>
              </div>
            ) : null}

            {product.shippingOptions.length > 0 ? (
              <div className="rounded-3xl border border-artisan-clay bg-card p-5">
                <h2 className="font-semibold">Shipping options</h2>
                <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
                  {product.shippingOptions.filter((option) => option.enabled).map((option) => (
                    <li key={option.key} className="flex justify-between gap-4">
                      <span>{option.key.replaceAll("_", " ")}</span>
                      <span>{formatPrice(option.price)}</span>
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}

            <AddToCartButton productId={product.id} disabled={product.stockQty <= 0} />
          </section>
        </main>
      </div>
    </GuestCartProvider>
  );
}
```

- [ ] **Step 5: Add Phase 1 cart status page**

Create `landing/src/app/cart/page.tsx`:

```tsx
"use client";

import Link from "next/link";

import { GuestCartProvider, useGuestCart } from "@/components/marketplace/guest-cart-provider";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";

function GuestCartStatus() {
  const { quantity } = useGuestCart();

  return (
    <main className="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:px-8">
      <div className="rounded-3xl border border-artisan-clay bg-card p-8 text-center shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.3em] text-artisan-terracotta">
          Guest cart
        </p>
        <h1 className="mt-4 text-3xl font-bold">Your cart foundation is ready</h1>
        <p className="mt-4 text-muted-foreground">
          {quantity > 0
            ? `You have ${quantity} item${quantity === 1 ? "" : "s"} saved in this browser. Full cart review and checkout come in Phase 2.`
            : "Add a product from the marketplace to save it in this browser. Full cart review and checkout come in Phase 2."}
        </p>
        <Button asChild className="mt-6 rounded-full">
          <Link href="/shop">Continue shopping</Link>
        </Button>
      </div>
    </main>
  );
}

export default function CartPage() {
  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-background">
        <MarketplaceHeader />
        <GuestCartStatus />
      </div>
    </GuestCartProvider>
  );
}
```

- [ ] **Step 6: Verify product and cart routes**

Run from `landing/`:

```powershell
npm run lint
npm run build
```

Expected: both commands pass.

- [ ] **Step 7: Commit product detail and guest cart foundation**

```powershell
git add landing/src/components/marketplace/guest-cart-provider.tsx landing/src/components/marketplace/add-to-cart-button.tsx landing/src/app/shop/layout.tsx landing/src/app/products/[productId]/page.tsx landing/src/app/cart/page.tsx
git commit -m "feat: add web product detail page"
```

## Task 8: Build Shop Profile Page

**Files:**

- Create: `landing/src/app/shops/[shopId]/page.tsx`

- [ ] **Step 1: Add shop profile page**

Create `landing/src/app/shops/[shopId]/page.tsx`:

```tsx
import Image from "next/image";
import { notFound } from "next/navigation";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ProductCard } from "@/components/marketplace/product-card";
import { Badge } from "@/components/ui/badge";
import { getMarketplaceShop } from "@/lib/marketplace/catalog";

type ShopPageProps = {
  params: Promise<{ shopId: string }>;
};

export async function generateMetadata({ params }: ShopPageProps) {
  const { shopId } = await params;
  const shop = await getMarketplaceShop(shopId);
  if (!shop) return { title: "Shop not found | Artisan Lane" };
  return {
    title: `${shop.name} | Artisan Lane`,
    description: shop.bio ?? `Shop handmade goods from ${shop.name} on Artisan Lane.`,
  };
}

export default async function ShopProfilePage({ params }: ShopPageProps) {
  const { shopId } = await params;
  const shop = await getMarketplaceShop(shopId);
  if (!shop) notFound();

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main>
        <section className="relative overflow-hidden bg-artisan-bone">
          <div className="absolute inset-0 opacity-30">
            {shop.coverImageUrl ? (
              <Image src={shop.coverImageUrl} alt="" fill priority sizes="100vw" className="object-cover" />
            ) : null}
          </div>
          <div className="relative mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
            <div className="flex flex-col gap-6 rounded-3xl bg-background/90 p-6 shadow-xl md:flex-row md:items-end">
              <div className="relative size-24 overflow-hidden rounded-3xl bg-secondary">
                <Image src={shop.logoUrl ?? "/logo.png"} alt={shop.name} fill sizes="96px" className="object-cover" />
              </div>
              <div className="flex-1">
                <div className="mb-3 flex flex-wrap gap-2">
                  {shop.isOffline ? <Badge variant="secondary">Temporarily offline</Badge> : <Badge>Open</Badge>}
                  {shop.location ? <Badge variant="outline">{shop.location}</Badge> : null}
                </div>
                <h1 className="text-4xl font-bold">{shop.name}</h1>
                {shop.bio ? <p className="mt-3 max-w-3xl text-muted-foreground">{shop.bio}</p> : null}
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
          {shop.brandStory ? (
            <div className="mb-10 rounded-3xl border border-artisan-clay bg-card p-6">
              <h2 className="text-2xl font-bold">Meet the maker</h2>
              <p className="mt-3 whitespace-pre-line text-muted-foreground">{shop.brandStory}</p>
            </div>
          ) : null}

          <div className="mb-6">
            <h2 className="text-2xl font-bold">Products from {shop.name}</h2>
            <p className="text-muted-foreground">{shop.productCount} products available</p>
          </div>
          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {shop.products.map((product) => <ProductCard key={product.id} product={product} />)}
          </div>
        </section>
      </main>
    </div>
  );
}
```

- [ ] **Step 2: Verify shop route**

Run from `landing/`:

```powershell
npm run lint
npm run build
```

Expected: both commands pass.

- [ ] **Step 3: Commit shop profile page**

```powershell
git add landing/src/app/shops/[shopId]/page.tsx
git commit -m "feat: add web shop profile page"
```

## Task 9: Final Phase 1 Verification

**Files:**

- Review all files touched in Phase 1.

- [ ] **Step 1: Run complete web verification**

Run from `landing/`:

```powershell
npm test
npm run lint
npm run build
```

Expected:

- `npm test` passes all marketplace helper tests.
- `npm run lint` exits 0.
- `npm run build` exits 0 and includes `/shop`, `/products/[productId]`, and `/shops/[shopId]`.

- [ ] **Step 2: Manually smoke-check routes**

Start the web app:

```powershell
npm run dev
```

Open:

- `http://localhost:3000/shop`
- `http://localhost:3000/products/<known-product-id>`
- `http://localhost:3000/shops/<known-shop-slug-or-id>`

Expected:

- `/shop` renders without crashing.
- Product cards link to product pages.
- Shop cards link to shop pages.
- Product page can add an item to guest cart storage.
- Shop page shows products from that shop.

- [ ] **Step 3: Commit final fixes if needed**

If verification required fixes:

```powershell
git add landing
git commit -m "fix: stabilize web marketplace phase one"
```

If no fixes were required, do not create an empty commit.

## Self-Review Checklist

- Phase 1 covers the approved spec's foundation and public marketplace work.
- Later-phase commerce, account, messaging, disputes, and reviews are intentionally excluded and remain in the design spec.
- Browser order creation is not introduced.
- Catalog reads filter published, non-archived products from active shops.
- Guest cart is local-only and does not imply checkout is complete.
- Tests cover pure helper behavior before route work starts.
