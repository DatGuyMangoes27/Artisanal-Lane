import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ShopCard } from "@/components/marketplace/shop-card";
import { getMarketplaceShops } from "@/lib/marketplace/catalog";

export default async function ArtisansPage() {
  const shops = await getMarketplaceShops(48);

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
              {shops.length} {shops.length === 1 ? "artisan" : "artisans"} listed
            </p>
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
        </section>
      </main>
    </div>
  );
}
