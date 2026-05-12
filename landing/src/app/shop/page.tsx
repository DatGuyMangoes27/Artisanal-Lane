import Link from "next/link";
import { Suspense } from "react";

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

function SearchControlsFallback() {
  return (
    <div className="grid gap-3 rounded-3xl border border-artisan-clay bg-card p-4 shadow-sm md:grid-cols-[1fr_220px_180px_auto]">
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
  const sort = params?.sort ?? "newest";

  const [categories, products, featuredProducts, freshProducts, shops] = await Promise.all([
    getMarketplaceCategories(),
    getMarketplaceProducts({ query, categoryId, sort }),
    getFeaturedMarketplaceProducts(8),
    getFreshMarketplaceProducts(8),
    getMarketplaceShops(12),
  ]);

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
                href="#artisans"
                className="inline-flex h-11 items-center justify-center rounded-full border border-artisan-clay bg-card px-6 text-sm font-semibold text-foreground shadow-sm transition hover:bg-secondary"
              >
                Meet the artisans
              </Link>
            </div>
          </div>
          <div className="rounded-[2rem] border border-artisan-clay bg-card/80 p-6 shadow-sm">
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-muted-foreground">
              Marketplace highlights
            </p>
            <div className="mt-6 grid grid-cols-2 gap-4">
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{products.length}</p>
                <p className="mt-1 text-sm text-muted-foreground">shop-ready products</p>
              </div>
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{shops.length}</p>
                <p className="mt-1 text-sm text-muted-foreground">artisan shops</p>
              </div>
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{featuredProducts.length}</p>
                <p className="mt-1 text-sm text-muted-foreground">featured finds</p>
              </div>
              <div className="rounded-3xl bg-background p-5">
                <p className="text-3xl font-bold text-artisan-terracotta">{categories.length}</p>
                <p className="mt-1 text-sm text-muted-foreground">categories</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
        <Suspense fallback={<SearchControlsFallback />}>
          <SearchControls categories={categories} />
        </Suspense>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
        <div className="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
              Shop products
            </p>
            <h2 className="mt-2 font-serif text-3xl font-bold text-foreground">Shop products</h2>
          </div>
          <p className="text-sm text-muted-foreground">{products.length} products found</p>
        </div>
        {products.length > 0 ? (
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {products.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        ) : (
          <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
            No products match your search yet. Try a different keyword or category.
          </p>
        )}
      </section>

      <section className="bg-artisan-bone/40 py-14">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="mb-6">
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
              Featured finds
            </p>
            <h2 className="mt-2 font-serif text-3xl font-bold text-foreground">Featured finds</h2>
          </div>
          {featuredProducts.length > 0 ? (
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
              {featuredProducts.map((product) => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          ) : (
            <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
              Featured products will appear here as artisans highlight their best work.
            </p>
          )}
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
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {freshProducts.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        ) : (
          <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
            New products will appear here as artisan shops publish fresh work.
          </p>
        )}
      </section>

      <section id="artisans" className="border-t border-artisan-clay/70 bg-card/50 py-14">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="mb-6">
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
              Meet the artisans
            </p>
            <h2 className="mt-2 font-serif text-3xl font-bold text-foreground">Meet the artisans</h2>
          </div>
          {shops.length > 0 ? (
            <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {shops.map((shop) => (
                <ShopCard key={shop.id} shop={shop} />
              ))}
            </div>
          ) : (
            <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
              Artisan shops will appear here as makers come online.
            </p>
          )}
        </div>
      </section>
    </main>
  );
}
