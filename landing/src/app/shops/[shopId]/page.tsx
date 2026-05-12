import type { Metadata } from "next";
import Image from "next/image";
import { notFound } from "next/navigation";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ProductCard } from "@/components/marketplace/product-card";
import { Badge } from "@/components/ui/badge";
import { getMarketplaceShop } from "@/lib/marketplace/catalog";

type ShopProfilePageProps = {
  params: Promise<{
    shopId: string;
  }>;
};

function getShopInitial(name: string) {
  return name.trim().charAt(0).toUpperCase() || "A";
}

export async function generateMetadata({ params }: ShopProfilePageProps): Promise<Metadata> {
  const { shopId } = await params;
  const shop = await getMarketplaceShop(shopId);

  if (!shop) {
    return {
      title: "Shop not found | Artisan Lane",
    };
  }

  return {
    title: `${shop.name} | Artisan Lane`,
    description: shop.bio ?? shop.brandStory ?? `Shop handcrafted pieces from ${shop.name}.`,
  };
}

export default async function ShopProfilePage({ params }: ShopProfilePageProps) {
  const { shopId } = await params;
  const shop = await getMarketplaceShop(shopId);

  if (!shop) {
    notFound();
  }

  const initial = getShopInitial(shop.name);
  const heroImage = shop.coverImageUrl ?? shop.logoUrl;

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main>
        <section className="relative overflow-hidden border-b border-artisan-clay/70 bg-gradient-to-br from-background via-artisan-bone/60 to-artisan-clay/40">
          <div className="absolute right-0 top-0 h-72 w-72 rounded-full bg-artisan-ochre/20 blur-3xl" />
          <div className="absolute bottom-0 left-0 h-80 w-80 rounded-full bg-artisan-terracotta/10 blur-3xl" />
          <div className="relative mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[0.95fr_1.05fr] lg:px-8 lg:py-14">
            <div className="relative min-h-[20rem] overflow-hidden rounded-[2rem] border border-artisan-clay bg-secondary shadow-sm">
              {heroImage ? (
                <Image
                  src={heroImage}
                  alt={shop.coverImageUrl ? `${shop.name} cover image` : `${shop.name} logo`}
                  fill
                  priority
                  sizes="(min-width: 1024px) 45vw, 100vw"
                  className={shop.coverImageUrl ? "object-cover" : "object-contain p-16"}
                />
              ) : (
                <div className="flex size-full min-h-[20rem] items-center justify-center bg-gradient-to-br from-artisan-terracotta via-artisan-clay to-artisan-ochre">
                  <span className="font-serif text-7xl font-bold text-white/95">{initial}</span>
                </div>
              )}
            </div>

            <div className="flex flex-col justify-center">
              <div className="mb-6 flex flex-wrap items-center gap-3">
                <Badge
                  variant={shop.isOffline ? "secondary" : "outline"}
                  className={shop.isOffline ? undefined : "border-artisan-terracotta text-artisan-terracotta"}
                >
                  {shop.isOffline ? "Offline" : "Open for orders"}
                </Badge>
                <Badge variant="secondary">{shop.location ?? "South Africa"}</Badge>
              </div>

              <div className="flex flex-col gap-5 sm:flex-row sm:items-center">
                <div className="relative size-24 shrink-0 overflow-hidden rounded-full border border-artisan-clay bg-secondary shadow-sm">
                  {shop.logoUrl ? (
                    <Image
                      src={shop.logoUrl}
                      alt={`${shop.name} logo`}
                      fill
                      sizes="96px"
                      className="object-cover"
                    />
                  ) : (
                    <div className="flex size-full items-center justify-center bg-gradient-to-br from-artisan-terracotta to-artisan-clay font-serif text-3xl font-bold text-white">
                      {initial}
                    </div>
                  )}
                </div>
                <div>
                  <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
                    Artisan shop
                  </p>
                  <h1 className="mt-3 font-serif text-5xl font-bold tracking-tight text-foreground md:text-6xl">
                    {shop.name}
                  </h1>
                </div>
              </div>

              <p className="mt-6 max-w-2xl text-lg leading-8 text-muted-foreground">
                {shop.bio ?? "This artisan is preparing their public shop story."}
              </p>
            </div>
          </div>
        </section>

        <section className="mx-auto grid max-w-7xl gap-8 px-4 py-12 sm:px-6 lg:grid-cols-[0.7fr_1.3fr] lg:px-8 lg:py-16">
          <aside className="h-fit rounded-[2rem] border border-artisan-clay bg-card p-6 shadow-sm">
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
              Shop details
            </p>
            <dl className="mt-5 space-y-4 text-sm">
              <div>
                <dt className="font-semibold text-foreground">Location</dt>
                <dd className="mt-1 text-muted-foreground">{shop.location ?? "South Africa"}</dd>
              </div>
              <div>
                <dt className="font-semibold text-foreground">Status</dt>
                <dd className="mt-1 text-muted-foreground">
                  {shop.isOffline ? "Currently offline" : "Open for orders"}
                </dd>
              </div>
              <div>
                <dt className="font-semibold text-foreground">Products</dt>
                <dd className="mt-1 text-muted-foreground">
                  {shop.products.length} {shop.products.length === 1 ? "public product" : "public products"}
                </dd>
              </div>
            </dl>
          </aside>

          <div className="space-y-10">
            <section className="space-y-3">
              <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                Brand story
              </p>
              <h2 className="font-serif text-3xl font-bold text-foreground">Meet the maker</h2>
              <p className="leading-8 text-muted-foreground">
                {shop.brandStory ?? "This artisan has not shared a brand story yet."}
              </p>
            </section>

            <section>
              <div className="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
                <div>
                  <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                    From this shop
                  </p>
                  <h2 className="mt-2 font-serif text-3xl font-bold text-foreground">{shop.name} products</h2>
                </div>
                <p className="text-sm text-muted-foreground">
                  {shop.products.length} {shop.products.length === 1 ? "product" : "products"} available
                </p>
              </div>

              {shop.products.length > 0 ? (
                <div className="grid gap-6 sm:grid-cols-2 xl:grid-cols-3">
                  {shop.products.map((product) => (
                    <ProductCard key={product.id} product={product} />
                  ))}
                </div>
              ) : (
                <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
                  Products from this artisan will appear here as soon as they are published.
                </p>
              )}
            </section>
          </div>
        </section>
      </main>
    </div>
  );
}
