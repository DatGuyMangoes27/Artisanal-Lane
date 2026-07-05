import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ShopCard } from "@/components/marketplace/shop-card";
import { getMarketplaceShops } from "@/lib/marketplace/catalog";

export default async function ArtisansPage() {
  const shops = await getMarketplaceShops(48);
  const activeShops = shops.filter((shop) => shop.productCount > 0);
  const comingSoonShops = shops.filter((shop) => shop.productCount === 0);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader activeItem="artisans" />
      <main>
        <section className="relative overflow-hidden border-b border-artisan-clay/70 bg-gradient-to-br from-background via-artisan-bone/50 to-artisan-clay/40">
          <div className="absolute right-0 top-0 h-72 w-72 rounded-full bg-artisan-ochre/20 blur-3xl" />
          <div className="absolute bottom-0 left-0 h-80 w-80 rounded-full bg-artisan-terracotta/10 blur-3xl" />
          <div className="relative mx-auto max-w-7xl px-4 py-12 sm:px-6 sm:py-16 lg:px-8 lg:py-24">
            <p className="mb-4 text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
              Artisan directory
            </p>
            <h1 className="max-w-3xl font-serif text-4xl font-bold leading-tight tracking-tight text-foreground sm:text-5xl md:text-6xl">
              Meet the makers behind the marketplace.
            </h1>
            <p className="mt-5 max-w-2xl text-base leading-7 text-muted-foreground sm:mt-6 sm:text-lg sm:leading-8">
              Explore every active artisan shop, read their stories, and browse their collections from one place.
            </p>
            <div className="mt-8 flex flex-col items-start gap-5 sm:flex-row sm:items-center">
              <Link
                href="/login?intent=vendor"
                className="inline-flex h-11 items-center justify-center rounded-full bg-artisan-terracotta px-6 text-sm font-semibold text-white shadow-sm transition hover:bg-artisan-terracotta-dark"
              >
                Apply as a shop
              </Link>
              <div
                className="inline-flex items-stretch overflow-hidden rounded-2xl shadow-sm"
                aria-label="0% commission and your first two months free"
              >
                <div className="flex flex-col justify-center bg-[#4B5320] px-4 py-2 text-white">
                  <span className="text-2xl font-extrabold leading-none">0%</span>
                  <span className="text-[10px] font-semibold uppercase tracking-[0.18em]">
                    Commission
                  </span>
                </div>
                <div className="flex flex-col justify-center bg-[#7A0000] px-4 py-2 text-white">
                  <span className="text-[10px] font-semibold uppercase tracking-[0.18em]">
                    Two months
                  </span>
                  <span className="text-2xl font-extrabold uppercase leading-none">Free</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 py-10 sm:px-6 sm:py-14 lg:px-8">
          <div className="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                All artisans
              </p>
              <h2 className="mt-2 font-serif text-2xl font-bold text-foreground sm:text-3xl">Artisan shops</h2>
            </div>
            <p className="text-sm text-muted-foreground">
              {activeShops.length} {activeShops.length === 1 ? "artisan" : "artisans"} listed
            </p>
          </div>

          {activeShops.length > 0 ? (
            <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {activeShops.map((shop) => (
                <ShopCard key={shop.id} shop={shop} />
              ))}
            </div>
          ) : (
            <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
              Artisan shops will appear here as makers come online.
            </p>
          )}

          {comingSoonShops.length > 0 ? (
            <div className="mt-12">
              <div className="mb-6">
                <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                  Coming soon
                </p>
                <h2 className="mt-2 font-serif text-2xl font-bold text-foreground sm:text-3xl">
                  New artisans setting up shop
                </h2>
                <p className="mt-2 text-sm text-muted-foreground">
                  These makers have joined Artisan Lane and are busy adding their first products.
                </p>
              </div>
              <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
                {comingSoonShops.map((shop) => (
                  <ShopCard key={shop.id} shop={shop} />
                ))}
              </div>
            </div>
          ) : null}
        </section>
      </main>
    </div>
  );
}
