import Link from "next/link";
import { Suspense } from "react";

import { ProductCarousel } from "@/components/marketplace/product-carousel";
import { ProductCard } from "@/components/marketplace/product-card";
import { SearchControls } from "@/components/marketplace/search-controls";
import { listFavouriteProductIds } from "@/lib/marketplace/buyer-preferences-data";
import {
  getFreshMarketplaceProducts,
  getFreshMarketplaceProductCount,
  getMarketplaceCategories,
  getMarketplaceProducts,
  getMarketplaceProductCount,
  getMarketplaceSubcategories,
  getMarketplaceShopCount,
  getTrendingSearchTerms,
  type MarketplaceAvailabilityFilter,
  type MarketplacePriceFilter,
  type MarketplaceProductSort,
} from "@/lib/marketplace/catalog";
import { createClient } from "@/lib/supabase/server";

type ShopSearchParams = {
  q?: string;
  category?: string;
  subcategory?: string;
  sort?: MarketplaceProductSort;
  price?: MarketplacePriceFilter;
  availability?: MarketplaceAvailabilityFilter;
  page?: string;
};

type ShopPageProps = {
  searchParams?: Promise<ShopSearchParams>;
};

const productsPerPage = 16;

function parseShopPage(value: string | undefined) {
  const page = Number(value);
  return Number.isFinite(page) && page > 0 ? Math.trunc(page) : 1;
}

function buildPageHref(params: ShopSearchParams | undefined, page: number) {
  const nextParams = new URLSearchParams(
    Object.entries(params ?? {}).filter((entry): entry is [string, string] => (
      typeof entry[1] === "string" && entry[1].length > 0
    )),
  );

  if (page <= 1) {
    nextParams.delete("page");
  } else {
    nextParams.set("page", String(page));
  }

  const queryString = nextParams.toString();
  return queryString ? `/shop?${queryString}` : "/shop";
}

function SearchControlsFallback() {
  return (
    <div className="grid gap-3 rounded-3xl border border-artisan-clay bg-card p-4 shadow-sm md:grid-cols-[1fr_170px_170px_150px_150px_140px_auto_auto]">
      <div className="h-11 rounded-full bg-secondary" />
      <div className="h-11 rounded-full bg-secondary" />
      <div className="h-11 rounded-full bg-secondary" />
      <div className="h-11 rounded-full bg-secondary" />
      <div className="h-11 rounded-full bg-secondary" />
      <div className="h-11 rounded-full bg-secondary" />
      <div className="h-11 rounded-full bg-secondary" />
      <div className="h-11 rounded-full bg-secondary" />
    </div>
  );
}

export default async function ShopPage({ searchParams }: ShopPageProps) {
  const params = await searchParams;
  const query = params?.q;
  const categoryId = params?.category;
  const subcategoryId = categoryId ? params?.subcategory : undefined;
  const sort = params?.sort ?? "newest";
  const priceFilter = params?.price;
  const availabilityFilter = params?.availability;
  const currentPage = parseShopPage(params?.page);
  const productOffset = (currentPage - 1) * productsPerPage;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [categories, subcategories, products, freshProducts, shopCount, productCount, freshCount, trendingTerms, favouriteIds] = await Promise.all([
    getMarketplaceCategories(),
    getMarketplaceSubcategories(),
    getMarketplaceProducts({
      query,
      categoryId,
      subcategoryId,
      sort,
      priceFilter,
      availabilityFilter,
      limit: productsPerPage + 1,
      offset: productOffset,
    }),
    getFreshMarketplaceProducts(8),
    getMarketplaceShopCount(),
    getMarketplaceProductCount(),
    getFreshMarketplaceProductCount(),
    getTrendingSearchTerms(8),
    user ? listFavouriteProductIds(user.id) : Promise.resolve([]),
  ]);
  const pageProducts = products.slice(0, productsPerPage);
  const hasNextPage = products.length > productsPerPage;
  const previousPageHref = buildPageHref(params, currentPage - 1);
  const nextPageHref = buildPageHref(params, currentPage + 1);
  const favouriteIdSet = new Set(favouriteIds);
  const shopQueryString = new URLSearchParams(
    Object.entries(params ?? {}).filter((entry): entry is [string, string] => typeof entry[1] === "string"),
  ).toString();
  const shopHref = shopQueryString ? `/shop?${shopQueryString}` : "/shop";

  return (
    <main>
      <section className="relative overflow-hidden border-b border-artisan-clay/70 bg-gradient-to-br from-background via-artisan-bone/50 to-artisan-clay/40">
        <div className="absolute right-0 top-0 h-72 w-72 rounded-full bg-artisan-ochre/20 blur-3xl" />
        <div className="absolute bottom-0 left-0 h-80 w-80 rounded-full bg-artisan-terracotta/10 blur-3xl" />
        <div className="relative mx-auto grid max-w-7xl gap-8 px-4 py-16 sm:px-6 lg:grid-cols-[1.15fr_0.85fr] lg:px-8 lg:py-24">
          <div className="max-w-3xl">
            <p className="mb-4 text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
              Public marketplace
            </p>
            <h1 className="font-serif text-5xl font-bold tracking-tight text-foreground md:text-6xl">
              Discover handcrafted pieces from South African artisans.
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-muted-foreground">
              Browse curated products, fresh arrivals, and independent maker shops in one web-native marketplace.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link
                href="#search"
                className="inline-flex h-11 items-center justify-center rounded-full bg-primary px-6 text-sm font-semibold text-primary-foreground shadow-sm transition hover:bg-artisan-terracotta-dark"
              >
                Search products
              </Link>
              <Link
                href="/artisans"
                className="inline-flex h-11 items-center justify-center rounded-full border border-artisan-clay bg-card px-6 text-sm font-semibold text-foreground shadow-sm transition hover:bg-secondary"
              >
                Meet the artisans
              </Link>
              <Link
                href="/login?intent=vendor"
                className="inline-flex h-11 items-center justify-center rounded-full border border-artisan-terracotta bg-card px-6 text-sm font-semibold text-artisan-terracotta shadow-sm transition hover:bg-artisan-terracotta hover:text-white"
              >
                Apply as a shop
              </Link>
            </div>
          </div>
          <div className="rounded-[2rem] border border-artisan-clay bg-card/80 p-6 shadow-sm">
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-muted-foreground">
              Marketplace highlights
            </p>
            <div className="mt-6 grid grid-cols-2 gap-4">
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{productCount}</p>
                <p className="mt-1 text-sm text-muted-foreground">products listed</p>
              </div>
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{shopCount}</p>
                <p className="mt-1 text-sm text-muted-foreground">artisan shops</p>
              </div>
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{freshCount}</p>
                <p className="mt-1 text-sm text-muted-foreground">fresh arrivals</p>
              </div>
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{categories.length}</p>
                <p className="mt-1 text-sm text-muted-foreground">categories</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-14 sm:px-6 lg:px-8">
        <div className="mb-6">
          <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
            Fresh arrivals
          </p>
          <h2 className="mt-2 font-serif text-3xl font-bold text-foreground">Fresh arrivals</h2>
        </div>
        {freshProducts.length > 0 ? (
          <ProductCarousel>
            {freshProducts.map((product) => (
              <ProductCard
                key={product.id}
                product={product}
                isFavourite={favouriteIdSet.has(product.id)}
                redirectTo={shopHref}
              />
            ))}
          </ProductCarousel>
        ) : (
          <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
            New products will appear here as artisan shops publish fresh work.
          </p>
        )}
      </section>

      <section className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
        <Suspense fallback={<SearchControlsFallback />}>
          <SearchControls categories={categories} subcategories={subcategories} trendingTerms={trendingTerms} />
        </Suspense>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
        <div className="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
              All products
            </p>
            <h2 className="mt-2 font-serif text-3xl font-bold text-foreground">All products</h2>
          </div>
          <p className="text-sm text-muted-foreground">Page {currentPage}</p>
        </div>
        {pageProducts.length > 0 ? (
          <>
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {pageProducts.map((product) => (
              <ProductCard
                key={product.id}
                product={product}
                isFavourite={favouriteIdSet.has(product.id)}
                redirectTo={shopHref}
              />
            ))}
          </div>
          <div className="mt-8 flex flex-col items-center justify-between gap-3 sm:flex-row">
            <p className="text-sm text-muted-foreground">
              Showing up to {productsPerPage} products per page.
            </p>
            <div className="flex gap-3">
              {currentPage > 1 ? (
                <Link
                  href={previousPageHref}
                  className="inline-flex h-10 items-center justify-center rounded-full border border-artisan-clay bg-card px-5 text-sm font-semibold text-foreground shadow-sm transition hover:bg-secondary"
                >
                  Previous
                </Link>
              ) : null}
              {hasNextPage ? (
                <Link
                  href={nextPageHref}
                  className="inline-flex h-10 items-center justify-center rounded-full bg-primary px-5 text-sm font-semibold text-primary-foreground shadow-sm transition hover:bg-artisan-terracotta-dark"
                >
                  Next
                </Link>
              ) : null}
            </div>
          </div>
          </>
        ) : (
          <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
            No products match your search yet. Try a different keyword or category.
          </p>
        )}
      </section>

    </main>
  );
}
