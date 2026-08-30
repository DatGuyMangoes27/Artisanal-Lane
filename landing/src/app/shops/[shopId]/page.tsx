import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  HeartHandshake,
  MapPin,
  MessageCircle,
  PackageCheck,
  ShieldCheck,
  Sparkles,
  Star,
  Store,
} from "lucide-react";

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

function formatDate(value: string) {
  return new Date(value).toLocaleDateString("en-ZA", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

function PostCard({ post, shopName }: { post: ShopPost; shopName: string }) {
  const image = post.mediaUrls[0] ?? null;

  return (
    <article className="group overflow-hidden rounded-[1.6rem] border border-[#E2CDB9] bg-[#FFFDF9] shadow-[0_14px_40px_rgba(58,23,17,0.06)]">
      {image ? (
        <div className="relative aspect-[5/4] overflow-hidden bg-[#EAD9CA]">
          <Image
            src={image}
            alt={`${shopName} studio update`}
            fill
            sizes="(min-width: 1024px) 30vw, (min-width: 640px) 50vw, 100vw"
            className="object-cover transition duration-700 ease-out group-hover:scale-[1.035]"
          />
        </div>
      ) : (
        <div className="flex aspect-[5/2] items-center justify-center bg-[radial-gradient(circle_at_top_left,rgba(212,160,32,0.18),transparent_40%),linear-gradient(135deg,#F7E7D7,#EEF1E4)]">
          <Sparkles className="size-7 text-artisan-terracotta" />
        </div>
      )}
      <div className="p-5 sm:p-6">
        <div className="flex items-center justify-between gap-4">
          <p className="text-[10px] font-bold uppercase tracking-[0.22em] text-artisan-terracotta">
            From the studio
          </p>
          <p className="shrink-0 text-[11px] text-muted-foreground">{formatDate(post.createdAt)}</p>
        </div>
        <p className="mt-4 line-clamp-6 text-sm leading-6 text-[#6B5040]">
          {post.caption || "This maker shared a new studio update."}
        </p>
      </div>
    </article>
  );
}

function MarketEventCard({ event }: { event: ShopMarketEvent }) {
  return (
    <article className="flex h-full flex-col rounded-[1.5rem] border border-[#DCC3AB] bg-white/80 p-5 shadow-[0_10px_30px_rgba(58,23,17,0.05)]">
      <span className="flex size-10 items-center justify-center rounded-full bg-[#F5E8DC] text-artisan-terracotta">
        <CalendarDays className="size-5" />
      </span>
      <p className="mt-5 font-serif text-xl font-bold leading-tight text-[#351711]">{event.marketName}</p>
      <p className="mt-2 flex items-start gap-2 text-sm text-[#6B5040]">
        <MapPin className="mt-0.5 size-4 shrink-0 text-artisan-terracotta" />
        {event.location}
      </p>
      <p className="mt-4 text-sm font-semibold text-artisan-terracotta">
        {formatDate(event.eventDate)}
        {event.timeLabel ? ` · ${event.timeLabel}` : ""}
      </p>
      {event.notes ? <p className="mt-3 text-sm leading-6 text-muted-foreground">{event.notes}</p> : null}
    </article>
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
  const publicShopPath = `/shops/${shop.slug ?? shop.id}`;
  const productLabel = `${shop.products.length} ${shop.products.length === 1 ? "piece" : "pieces"}`;

  return (
    <div className="min-h-screen bg-[#FFF9F2]">
      <MarketplaceHeader />
      <main>
        <section className="relative isolate overflow-hidden bg-[#351711] text-white">
          {shop.coverImageUrl ? (
            <Image
              src={shop.coverImageUrl}
              alt={`${shop.name} cover image`}
              fill
              priority
              sizes="100vw"
              className="-z-20 object-cover"
            />
          ) : null}
          <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_80%_18%,rgba(212,160,32,0.28),transparent_28%),radial-gradient(circle_at_12%_82%,rgba(85,152,38,0.18),transparent_26%),linear-gradient(100deg,rgba(36,16,12,0.96)_10%,rgba(53,23,17,0.86)_52%,rgba(53,23,17,0.44)_100%)]" />
          <div className="absolute inset-0 -z-10 bg-gradient-to-t from-[#24100C]/90 via-transparent to-[#24100C]/15" />

          <div className="mx-auto flex min-h-[520px] max-w-[1500px] flex-col px-5 py-7 sm:px-8 lg:min-h-[610px] lg:px-14 xl:px-20">
            <Link
              href="/artisans"
              className="inline-flex w-fit items-center gap-2 text-xs font-semibold text-white/75 transition hover:text-white"
            >
              <ArrowLeft className="size-4" /> Back to artisans
            </Link>

            <div className="mt-auto max-w-5xl pb-5 pt-20">
              <div className="flex flex-col gap-6 sm:flex-row sm:items-end">
                <div className="relative size-24 shrink-0 overflow-hidden rounded-[1.6rem] border-4 border-white/85 bg-[#F4E6D9] shadow-2xl sm:size-32 sm:rounded-[2rem]">
                  {shop.logoUrl ? (
                    <Image src={shop.logoUrl} alt={`${shop.name} logo`} fill sizes="128px" className="object-cover" />
                  ) : (
                    <div className="flex size-full items-center justify-center bg-gradient-to-br from-artisan-terracotta via-[#9A2C12] to-[#D4A020] font-serif text-4xl font-bold text-white">
                      {initial}
                    </div>
                  )}
                </div>

                <div className="min-w-0 flex-1">
                  <div className="mb-4 flex flex-wrap items-center gap-2">
                    <Badge className={shop.isOffline ? "rounded-full bg-white/15 text-white" : "rounded-full bg-[#F5E8DC] text-[#7A0000]"}>
                      {shop.isOffline ? "Currently offline" : "Open for orders"}
                    </Badge>
                    <Badge className="rounded-full bg-white/15 text-white backdrop-blur" variant="secondary">
                      <MapPin className="mr-1 size-3" /> {shop.location ?? "South Africa"}
                    </Badge>
                    {reviewSummary.reviewCount > 0 ? (
                      <Badge className="rounded-full bg-white/15 text-white backdrop-blur" variant="secondary">
                        <Star className="mr-1 size-3 fill-[#F0D18F] text-[#F0D18F]" />
                        {reviewSummary.averageRating.toFixed(1)} · {reviewSummary.reviewCount} reviews
                      </Badge>
                    ) : null}
                  </div>
                  <p className="text-[10px] font-bold uppercase tracking-[0.25em] text-[#F0D18F]">
                    Independent South African studio
                  </p>
                  <h1 className="mt-3 max-w-4xl break-words font-serif text-4xl font-bold leading-[0.95] tracking-[-0.04em] [overflow-wrap:anywhere] sm:text-6xl lg:text-7xl">
                    {shop.name}
                  </h1>
                  <p className="mt-5 max-w-3xl text-base leading-7 text-[#F3E8DE]/90 sm:text-lg">
                    {shop.bio ?? "Discover handmade work created with care by this independent Artisan Lane maker."}
                  </p>
                </div>
              </div>

              <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
                <Button asChild size="lg" className="rounded-full bg-white px-7 text-[#351711] hover:bg-[#F1E2D3]">
                  <Link href="#collection">
                    Shop the collection <ArrowRight className="ml-2 size-4" />
                  </Link>
                </Button>
                <form action={createBuyerThreadForShop}>
                  <input type="hidden" name="shopId" value={shop.id} />
                  <input type="hidden" name="redirectTo" value={publicShopPath} />
                  <Button type="submit" size="lg" variant="outline" className="w-full rounded-full border-white/40 bg-white/10 px-7 text-white backdrop-blur hover:bg-white hover:text-[#351711] sm:w-auto">
                    <MessageCircle className="mr-2 size-4" /> Message the maker
                  </Button>
                </form>
              </div>
            </div>
          </div>
        </section>

        <nav className="sticky top-[72px] z-30 border-b border-[#E7D4C2] bg-[#FFF9F2]/95 backdrop-blur-xl lg:top-[76px]" aria-label="Shop sections">
          <div className="mx-auto flex max-w-[1440px] items-center gap-6 overflow-x-auto px-5 py-4 text-xs font-bold text-[#6B5040] sm:px-8">
            <Link href="#collection" className="shrink-0 text-[#8F120D]">Collection</Link>
            <Link href="#story" className="shrink-0 transition hover:text-[#8F120D]">Our story</Link>
            {posts.length > 0 ? <Link href="#studio" className="shrink-0 transition hover:text-[#8F120D]">From the studio</Link> : null}
            {marketEvents.length > 0 ? <Link href="#markets" className="shrink-0 transition hover:text-[#8F120D]">Find us in person</Link> : null}
            <span className="ml-auto hidden shrink-0 text-muted-foreground sm:block">{productLabel} in this shop</span>
          </div>
        </nav>

        <section className="border-b border-[#E7D4C2] bg-[linear-gradient(90deg,#F7EBDD_0%,#FFF9F2_52%,#F0F3E6_100%)]">
          <div className="mx-auto grid max-w-[1440px] gap-4 px-5 py-6 sm:grid-cols-2 sm:px-8 lg:grid-cols-4 lg:divide-x lg:divide-[#DCC3AB]">
            {[
              [Store, productLabel, "Curated shop collection"],
              [PackageCheck, shop.isOffline ? "Shop paused" : "Taking orders", "Availability set by the maker"],
              [ShieldCheck, "Protected payment", "TradeSafe checkout protection"],
              [HeartHandshake, "Direct from the maker", "Support an independent studio"],
            ].map(([Icon, title, copy]) => (
              <div key={String(title)} className="flex items-center gap-3 lg:px-6 first:pl-0">
                <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-white text-artisan-terracotta shadow-sm">
                  <Icon className="size-4" />
                </span>
                <div>
                  <p className="text-xs font-bold text-[#351711]">{String(title)}</p>
                  <p className="mt-0.5 text-[11px] text-muted-foreground">{String(copy)}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section id="collection" className="mx-auto max-w-[1440px] scroll-mt-40 px-5 py-16 sm:px-8 sm:py-24">
          <div className="mb-9 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
            <div>
              <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-artisan-terracotta">The collection</p>
              <h2 className="mt-3 max-w-3xl font-serif text-3xl font-bold leading-tight text-[#351711] sm:text-5xl">
                Handmade by <span className="gradient-text italic">{shop.name}</span>
              </h2>
            </div>
            <p className="text-sm text-muted-foreground">{productLabel} available</p>
          </div>

          {shop.products.length > 0 ? (
            <div className="grid gap-x-5 gap-y-10 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              {shop.products.map((product) => (
                <ProductCard key={product.id} product={product} redirectTo={publicShopPath} />
              ))}
            </div>
          ) : (
            <div className="rounded-[2rem] border border-[#DCC3AB] bg-white p-8 text-center shadow-sm">
              <Store className="mx-auto size-8 text-artisan-terracotta" />
              <h3 className="mt-4 font-serif text-2xl font-bold text-[#351711]">The collection is being prepared</h3>
              <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-muted-foreground">
                Products from this artisan will appear here as soon as they are published.
              </p>
            </div>
          )}
        </section>

        <section id="story" className="scroll-mt-40 overflow-hidden bg-[linear-gradient(135deg,#351711_0%,#50160F_62%,#314522_135%)] text-[#FFF8F0]">
          <div className="mx-auto grid max-w-[1440px] lg:grid-cols-[0.72fr_1.28fr]">
            <div className="flex flex-col justify-between border-b border-white/10 px-6 py-14 sm:px-10 lg:border-b-0 lg:border-r lg:px-14 lg:py-20">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-[#E5B35A]">The person behind the pieces</p>
                <div className="mt-6 flex items-center gap-4">
                  <div className="relative size-16 shrink-0 overflow-hidden rounded-full border border-white/25 bg-white/10">
                    {shop.artisanAvatarUrl ? (
                      <Image src={shop.artisanAvatarUrl} alt={shop.artisanName ?? "The artisan"} fill sizes="64px" className="object-cover" />
                    ) : (
                      <div className="flex size-full items-center justify-center font-serif text-2xl font-bold">{initial}</div>
                    )}
                  </div>
                  <div>
                    <p className="font-serif text-2xl font-bold">{shop.artisanName ?? shop.name}</p>
                    <p className="mt-1 flex items-center gap-1.5 text-sm text-[#D9BFA9]"><MapPin className="size-3.5" />{shop.location ?? "South Africa"}</p>
                  </div>
                </div>
              </div>
              <p className="mt-10 border-l border-[#E5B35A]/60 pl-4 text-sm leading-6 text-[#D9BFA9]">
                Every order supports an independent South African creative business.
              </p>
            </div>

            <div className="px-6 py-14 sm:px-10 lg:px-16 lg:py-20">
              <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-[#E5B35A]">Our story</p>
              <h2 className="mt-4 font-serif text-4xl font-bold leading-tight sm:text-5xl">Meet the maker</h2>
              <p className="mt-7 max-w-3xl whitespace-pre-line text-base leading-8 text-[#EAD9CA]">
                {shop.brandStory ?? "This artisan is still writing their story. Explore the collection to discover the work they are bringing to Artisan Lane."}
              </p>
            </div>
          </div>
        </section>

        {posts.length > 0 ? (
          <section id="studio" className="mx-auto max-w-[1440px] scroll-mt-40 px-5 py-16 sm:px-8 sm:py-24">
            <div className="mb-9 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-artisan-terracotta">Behind the work</p>
                <h2 className="mt-3 font-serif text-3xl font-bold text-[#351711] sm:text-5xl">From the studio</h2>
                <p className="mt-3 max-w-2xl text-sm leading-6 text-muted-foreground">New work, process notes and moments shared by the maker.</p>
              </div>
              <p className="text-sm text-muted-foreground">{posts.length} latest {posts.length === 1 ? "update" : "updates"}</p>
            </div>
            <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
              {posts.map((post) => <PostCard key={post.id} post={post} shopName={shop.name} />)}
            </div>
          </section>
        ) : null}

        {marketEvents.length > 0 ? (
          <section id="markets" className="scroll-mt-40 border-y border-[#E7D4C2] bg-[radial-gradient(circle_at_12%_16%,rgba(212,160,32,0.11),transparent_28%),radial-gradient(circle_at_88%_82%,rgba(85,152,38,0.08),transparent_30%),#F8EEE3]">
            <div className="mx-auto max-w-[1440px] px-5 py-16 sm:px-8 sm:py-24">
              <div className="mb-9 max-w-2xl">
                <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-artisan-terracotta">Shop in person</p>
                <h2 className="mt-3 font-serif text-3xl font-bold text-[#351711] sm:text-5xl">Find us at a market</h2>
                <p className="mt-3 text-sm leading-6 text-muted-foreground">Meet the maker and experience the work up close at these upcoming events.</p>
              </div>
              <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
                {marketEvents.map((event) => <MarketEventCard key={event.id} event={event} />)}
              </div>
            </div>
          </section>
        ) : null}

        <section className="px-5 py-16 sm:px-8 sm:py-20">
          <div className="mx-auto flex max-w-[1180px] flex-col items-start justify-between gap-7 border-y border-[#D9BFA9] py-10 sm:flex-row sm:items-center">
            <div>
              <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-artisan-terracotta">A more personal way to shop</p>
              <h2 className="mt-3 font-serif text-3xl font-bold text-[#351711]">Have a question about a piece?</h2>
              <p className="mt-2 text-sm text-muted-foreground">Ask the maker about materials, sizing, availability or a custom request.</p>
            </div>
            <form action={createBuyerThreadForShop} className="shrink-0">
              <input type="hidden" name="shopId" value={shop.id} />
              <input type="hidden" name="redirectTo" value={publicShopPath} />
              <Button type="submit" size="lg" className="rounded-full bg-[#8F120D] px-7">
                <MessageCircle className="mr-2 size-4" /> Message the maker
              </Button>
            </form>
          </div>
        </section>
      </main>
    </div>
  );
}
