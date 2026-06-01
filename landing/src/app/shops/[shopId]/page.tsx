import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ProductCard } from "@/components/marketplace/product-card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { getMarketplaceShop } from "@/lib/marketplace/catalog";
import {
  getShopReviewSummary,
  listShopMarketEvents,
  listShopPosts,
  type ShopMarketEvent,
  type ShopPost,
} from "@/lib/marketplace/shop-profile-data";

import { createBuyerThreadForShop } from "../../account/messages/actions";

type ShopProfilePageProps = {
  params: Promise<{
    shopId: string;
  }>;
};

function getShopInitial(name: string) {
  return name.trim().charAt(0).toUpperCase() || "A";
}

function PostCard({ post, shopName }: { post: ShopPost; shopName: string }) {
  const image = post.mediaUrls[0] ?? null;

  return (
    <article className="overflow-hidden rounded-[1.75rem] border border-artisan-clay bg-card shadow-sm">
      {image ? (
        <div className="relative aspect-[4/3] bg-secondary">
          <Image
            src={image}
            alt={`${shopName} post image`}
            fill
            sizes="(min-width: 1024px) 33vw, 100vw"
            className="object-cover"
          />
        </div>
      ) : null}
      <div className="p-5">
        <p className="text-sm font-semibold uppercase tracking-[0.2em] text-artisan-terracotta">
          Maker update
        </p>
        <p className="mt-3 leading-7 text-muted-foreground">
          {post.caption || "This maker shared a new shop update."}
        </p>
        <p className="mt-4 text-xs text-muted-foreground">
          {new Date(post.createdAt).toLocaleDateString("en-ZA", {
            year: "numeric",
            month: "long",
            day: "numeric",
          })}
        </p>
      </div>
    </article>
  );
}

function MarketEventCard({ event }: { event: ShopMarketEvent }) {
  return (
    <div className="rounded-2xl border border-artisan-clay bg-background p-4">
      <p className="font-semibold text-foreground">{event.marketName}</p>
      <p className="mt-1 text-sm text-muted-foreground">{event.location}</p>
      <p className="mt-2 text-sm font-medium text-artisan-terracotta">
        {new Date(event.eventDate).toLocaleDateString("en-ZA", {
          day: "numeric",
          month: "long",
          year: "numeric",
        })}
        {event.timeLabel ? ` • ${event.timeLabel}` : ""}
      </p>
      {event.notes ? <p className="mt-2 text-sm leading-6 text-muted-foreground">{event.notes}</p> : null}
    </div>
  );
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

  const [posts, marketEvents, reviewSummary] = await Promise.all([
    listShopPosts(shop.id),
    listShopMarketEvents(shop.id),
    getShopReviewSummary(shop.id),
  ]);
  const initial = getShopInitial(shop.name);
  const heroImage = shop.coverImageUrl ?? shop.logoUrl;
  const publicShopPath = `/shops/${shop.slug ?? shop.id}`;

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main>
        <section className="relative border-b border-artisan-clay/70">
          <div className="relative min-h-[16rem] overflow-hidden bg-gradient-to-br from-artisan-terracotta via-artisan-sienna to-artisan-ochre sm:min-h-[22rem]">
            {heroImage ? (
              <Image
                src={heroImage}
                alt={shop.coverImageUrl ? `${shop.name} cover image` : `${shop.name} logo`}
                fill
                priority
                sizes="100vw"
                className="object-cover"
              />
            ) : null}
            <div className="absolute inset-0 bg-gradient-to-t from-background via-background/45 to-background/15" />
            <div className="absolute inset-0 pattern-bg opacity-20" />
          </div>

          <div className="mx-auto max-w-7xl px-3 pb-10 sm:px-6 lg:px-8">
            <div className="relative -mt-24 rounded-[1.5rem] border border-artisan-clay bg-card/95 p-4 shadow-2xl shadow-artisan-terracotta/10 backdrop-blur sm:-mt-28 sm:rounded-[2rem] sm:p-6 md:p-8">
              <Button asChild variant="ghost" className="mb-6 rounded-full">
                <Link href="/artisans">Back to artisans</Link>
              </Button>
              <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
                <div className="flex min-w-0 flex-col gap-5 sm:flex-row sm:items-end">
                  <div className="relative size-20 shrink-0 overflow-hidden rounded-[1.5rem] border-4 border-card bg-secondary shadow-lg sm:size-28 sm:rounded-[2rem]">
                    {shop.logoUrl ? (
                      <Image
                        src={shop.logoUrl}
                        alt={`${shop.name} logo`}
                        fill
                        sizes="112px"
                        className="object-cover"
                      />
                    ) : (
                      <div className="flex size-full items-center justify-center bg-gradient-to-br from-artisan-terracotta to-artisan-clay font-serif text-3xl font-bold text-white sm:text-4xl">
                        {initial}
                      </div>
                    )}
                  </div>
                  <div className="min-w-0">
                    <div className="mb-3 flex flex-wrap items-center gap-3">
                      <Badge
                        variant={shop.isOffline ? "secondary" : "outline"}
                        className={shop.isOffline ? undefined : "border-artisan-terracotta text-artisan-terracotta"}
                      >
                        {shop.isOffline ? "Offline" : "Open for orders"}
                      </Badge>
                      <Badge variant="secondary">{shop.location ?? "South Africa"}</Badge>
                      {reviewSummary.reviewCount > 0 ? (
                        <Badge variant="secondary">
                          {reviewSummary.averageRating.toFixed(1)} stars • {reviewSummary.reviewCount} reviews
                        </Badge>
                      ) : null}
                    </div>
                    <p className="text-xs font-semibold uppercase tracking-[0.24em] text-artisan-terracotta sm:text-sm sm:tracking-[0.28em]">
                      Artisan profile
                    </p>
                    <h1 className="mt-3 max-w-full break-words font-serif text-4xl font-bold leading-[0.95] tracking-tight text-foreground [overflow-wrap:anywhere] sm:text-5xl md:text-6xl">
                      {shop.name}
                    </h1>
                    <p className="mt-4 max-w-3xl text-base leading-7 text-muted-foreground sm:text-lg sm:leading-8">
                      {shop.bio ?? "This artisan is preparing their public shop story."}
                    </p>
                  </div>
                </div>
                <form action={createBuyerThreadForShop} className="shrink-0">
                  <input type="hidden" name="shopId" value={shop.id} />
                  <input type="hidden" name="redirectTo" value={publicShopPath} />
                  <Button type="submit" size="lg" className="w-full rounded-full lg:w-auto">
                    Message artisan
                  </Button>
                </form>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto grid max-w-7xl gap-8 px-3 py-10 sm:px-6 sm:py-12 lg:grid-cols-[0.7fr_1.3fr] lg:px-8 lg:py-16">
          <aside className="space-y-6">
            <div className="h-fit rounded-[2rem] border border-artisan-clay bg-card p-6 shadow-sm">
              <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                Mini profile
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
                  <dt className="font-semibold text-foreground">Collection</dt>
                  <dd className="mt-1 text-muted-foreground">
                    {shop.products.length} {shop.products.length === 1 ? "public product" : "public products"}
                  </dd>
                </div>
                <div>
                  <dt className="font-semibold text-foreground">Updates</dt>
                  <dd className="mt-1 text-muted-foreground">
                    {posts.length} {posts.length === 1 ? "post" : "posts"}
                  </dd>
                </div>
              </dl>
            </div>

            {marketEvents.length > 0 ? (
              <div className="rounded-[2rem] border border-artisan-clay bg-card p-6 shadow-sm">
                <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                  Upcoming markets
                </p>
                <div className="mt-5 space-y-3">
                  {marketEvents.map((event) => (
                    <MarketEventCard key={event.id} event={event} />
                  ))}
                </div>
              </div>
            ) : null}
          </aside>

          <div className="space-y-10">
            <section className="rounded-[1.5rem] border border-artisan-clay bg-card p-4 shadow-sm sm:rounded-[2rem] sm:p-6">
              <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                Brand story
              </p>
              <h2 className="mt-2 font-serif text-2xl font-bold text-foreground sm:text-3xl">Meet the maker</h2>
              <p className="mt-4 leading-8 text-muted-foreground">
                {shop.brandStory ?? "This artisan has not shared a brand story yet."}
              </p>
            </section>

            <section>
              <div className="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
                <div>
                  <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                    Posts & updates
                  </p>
                  <h2 className="mt-2 font-serif text-2xl font-bold text-foreground sm:text-3xl">From the studio</h2>
                </div>
                <p className="text-sm text-muted-foreground">
                  {posts.length > 0 ? `${posts.length} latest ${posts.length === 1 ? "post" : "posts"}` : "No posts yet"}
                </p>
              </div>

              {posts.length > 0 ? (
                <div className="grid gap-6 md:grid-cols-2">
                  {posts.map((post) => (
                    <PostCard key={post.id} post={post} shopName={shop.name} />
                  ))}
                </div>
              ) : (
                <p className="rounded-3xl border border-artisan-clay bg-card p-6 text-sm text-muted-foreground">
                  This maker has not shared any updates yet. Check back soon for behind-the-scenes posts.
                </p>
              )}
            </section>

            <section>
              <div className="mb-6 flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
                <div>
                  <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
                    Collection
                  </p>
                  <h2 className="mt-2 break-words font-serif text-2xl font-bold text-foreground [overflow-wrap:anywhere] sm:text-3xl">
                    {shop.name} products
                  </h2>
                </div>
                <p className="text-sm text-muted-foreground">
                  {shop.products.length} {shop.products.length === 1 ? "product" : "products"} available
                </p>
              </div>

              {shop.products.length > 0 ? (
                <div className="grid gap-6 sm:grid-cols-2 xl:grid-cols-3">
                  {shop.products.map((product) => (
                    <ProductCard key={product.id} product={product} redirectTo={publicShopPath} />
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
