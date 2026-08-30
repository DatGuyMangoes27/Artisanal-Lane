import Image from "next/image";
import Link from "next/link";
import {
  ArrowRight,
  ChevronRight,
  Heart,
  PackageCheck,
  ShieldCheck,
  Sparkles,
  Store,
  Truck,
} from "lucide-react";

import { FeaturedFindsCarousel } from "@/components/marketplace/featured-finds-carousel";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ProductCarousel } from "@/components/marketplace/product-carousel";
import { ProductCard } from "@/components/marketplace/product-card";
import { Button } from "@/components/ui/button";
import { listFavouriteProductIds } from "@/lib/marketplace/buyer-preferences-data";
import {
  getFeaturedMarketplaceProducts,
  getFreshMarketplaceProducts,
  getMarketplaceCategories,
} from "@/lib/marketplace/catalog";
import { getProductPrimaryImage } from "@/lib/marketplace/format";
import type { MarketplaceCategorySummary, MarketplaceProduct } from "@/lib/marketplace/types";
import { createClient } from "@/lib/supabase/server";

const categoryFallbacks = ["Home", "Jewellery", "Self Care", "Clothing", "Baby & Kids", "Art & Design"];

function categoryHref(category: MarketplaceCategorySummary) {
  return `/shop?category=${encodeURIComponent(category.id)}`;
}

function Hero({ products }: { products: MarketplaceProduct[] }) {
  return (
    <section className="relative overflow-hidden border-b border-[#E7D4C2] bg-[#F8EEE3]">
      <div className="pointer-events-none absolute -left-48 -top-52 size-[38rem] rounded-full bg-gradient-to-br from-[#7A0000]/15 via-[#D4A020]/10 to-transparent blur-[95px]" />
      <div className="pointer-events-none absolute -bottom-56 left-[24%] size-[34rem] rounded-full bg-gradient-to-tr from-[#559826]/10 via-[#D4A020]/8 to-transparent blur-[95px]" />
      <div className="relative mx-auto grid min-h-[690px] max-w-[1500px] lg:grid-cols-[0.86fr_1.14fr]">
        <div className="relative z-10 flex items-center px-5 py-20 sm:px-8 lg:px-14 xl:px-20">
          <div className="max-w-[35rem]">
            <p className="mb-6 flex items-center gap-2 text-[10px] font-bold uppercase tracking-[0.24em] text-[#8F2415]">
              <span className="flex size-8 items-center justify-center rounded-full bg-gradient-to-br from-[#7A0000]/15 via-[#D4A020]/15 to-[#559826]/15"><Sparkles className="size-4" /></span> Curated South African craft
            </p>
            <h1 className="font-serif text-[3.65rem] font-bold leading-[0.92] tracking-[-0.055em] text-[#351711] sm:text-7xl xl:text-[5.65rem]">
              Beautiful things,<br /><span className="gradient-text italic">made slowly.</span>
            </h1>
            <p className="mt-8 max-w-lg text-base leading-7 text-[#6B5040] sm:text-lg">
              A considered collection of objects, gifts and everyday treasures made by independent artisans across South Africa.
            </p>
            <div className="mt-9 flex flex-wrap items-center gap-5">
              <Button asChild size="lg" className="h-13 rounded-full bg-gradient-to-r from-[#7A0000] via-[#9A2C12] to-[#8B4513] px-8 text-white shadow-[0_12px_30px_rgba(143,18,13,0.2)] transition hover:brightness-95"><Link href="/shop">Explore the collection <ArrowRight className="ml-2 size-4" /></Link></Button>
              <Link href="/artisans" className="group inline-flex items-center gap-2 text-sm font-semibold text-[#60483B]">Meet the makers <ArrowRight className="size-4 transition group-hover:translate-x-1" /></Link>
            </div>
            <p className="mt-10 max-w-sm border-l border-[#CBAE95] pl-4 text-xs leading-5 text-[#8B6C59]">Every shop is independently owned. Every product has a person and a process behind it.</p>
          </div>
        </div>
        <FeaturedFindsCarousel products={products} />
      </div>
    </section>
  );
}

function CategoryRail({ categories, products }: { categories: MarketplaceCategorySummary[]; products: MarketplaceProduct[] }) {
  const displayed = categories.filter((category) => categoryFallbacks.includes(category.name)).slice(0, 4);
  const categoryList = displayed.length >= 4 ? displayed : categories.slice(0, 4);

  return (
    <section className="bg-[radial-gradient(circle_at_12%_16%,rgba(212,160,32,0.09),transparent_27%),radial-gradient(circle_at_88%_82%,rgba(85,152,38,0.07),transparent_29%),#FFF9F2] py-20 sm:py-28">
      <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
        <div className="mb-10 flex items-end justify-between">
          <div>
            <p className="text-[10px] font-bold uppercase tracking-[0.22em] text-artisan-terracotta">The collection</p>
            <h2 className="mt-3 font-serif text-3xl font-bold text-[#351711] sm:text-[2.75rem]">Browse a <span className="gradient-text italic">thoughtful edit</span></h2>
          </div>
          <Link href="/shop" className="hidden items-center gap-2 text-sm font-semibold text-artisan-terracotta hover:underline sm:flex">Shop everything <ArrowRight className="size-4" /></Link>
        </div>
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4 lg:gap-5">
          {categoryList.map((category, index) => {
            const matching = products.find((product) => product.category?.id === category.id) ?? products[index % Math.max(products.length, 1)];
            return (
              <Link key={category.id} href={categoryHref(category)} className="group relative aspect-[4/5] overflow-hidden rounded-[1.6rem] bg-[#EAD9CA]">
                {matching ? <Image src={getProductPrimaryImage(matching)} alt="" fill sizes="(min-width: 1024px) 16vw, 50vw" className="object-cover transition duration-700 group-hover:scale-105" /> : null}
                <div className="absolute inset-0 bg-gradient-to-t from-[#351711]/80 via-transparent to-transparent" />
                <div className="absolute inset-x-5 bottom-5 flex items-center justify-between gap-2 text-white">
                  <span className="font-serif text-xl font-semibold leading-tight sm:text-2xl">{category.name === "Home" ? "Home & Living" : category.name}</span>
                  <span className="flex size-9 shrink-0 items-center justify-center rounded-full border border-white/40 bg-white/10 backdrop-blur"><ChevronRight className="size-4 transition group-hover:translate-x-0.5" /></span>
                </div>
              </Link>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function ProductEdit({ products, favouriteIds }: { products: MarketplaceProduct[]; favouriteIds: string[] }) {
  const favouriteSet = new Set(favouriteIds);
  return (
    <section className="border-y border-artisan-clay/70 bg-[linear-gradient(135deg,#F7E4CC_0%,#FFF9F2_48%,#F0F3E6_100%)] py-20 sm:py-28">
      <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
        <div className="mb-10 flex flex-col justify-between gap-5 sm:flex-row sm:items-end">
          <div>
            <p className="text-[11px] font-bold uppercase tracking-[0.22em] text-artisan-terracotta">New this week</p>
            <h2 className="mt-3 font-serif text-3xl font-bold text-[#351711] sm:text-[2.75rem]">New, noteworthy, <span className="gradient-text italic">handmade</span></h2>
            <p className="mt-2 text-sm text-muted-foreground">A quiet look at what our makers added this week.</p>
          </div>
          <Button asChild variant="outline" className="w-fit rounded-full border-artisan-terracotta/30 px-6"><Link href="/shop">View all products <ArrowRight className="ml-2 size-4" /></Link></Button>
        </div>
        <ProductCarousel>{products.slice(0, 15).map((product) => <ProductCard key={product.id} product={product} isFavourite={favouriteSet.has(product.id)} redirectTo="/" />)}</ProductCarousel>
      </div>
    </section>
  );
}

function MarketplaceStory({ products }: { products: MarketplaceProduct[] }) {
  const imageProduct = products[3] ?? products[0];
  return (
    <section className="bg-[linear-gradient(135deg,#351711_0%,#50160F_62%,#314522_135%)] text-[#FFF8F0]">
      <div className="mx-auto grid max-w-[1440px] lg:grid-cols-2">
        <div className="relative min-h-[460px] lg:min-h-[620px]">
          {imageProduct ? <Image src={getProductPrimaryImage(imageProduct)} alt={imageProduct.title} fill sizes="50vw" className="object-cover" /> : null}
          <div className="absolute inset-0 bg-gradient-to-r from-transparent to-[#351711]/35" />
        </div>
        <div className="flex items-center px-6 py-16 sm:px-12 lg:px-16">
          <div className="max-w-lg">
            <p className="text-[11px] font-bold uppercase tracking-[0.22em] text-[#E5B35A]">Meet the makers</p>
            <h2 className="mt-4 font-serif text-4xl font-bold leading-tight sm:text-5xl">Every purchase keeps a creative story moving.</h2>
            <p className="mt-6 leading-7 text-[#EAD9CA]">Artisan Lane brings independent South African studios into one curated marketplace. Explore the person behind the piece, shop their collection and support craftsmanship that cannot be mass-produced.</p>
            <Button asChild className="mt-8 rounded-full bg-[#FFF8F0] px-7 text-[#351711] hover:bg-[#EAD9CA]"><Link href="/artisans"><Store className="mr-2 size-4" />Discover our artisans</Link></Button>
          </div>
        </div>
      </div>
    </section>
  );
}

function TrustRow() {
  const items = [
    [ShieldCheck, "Protected payments", "TradeSafe holds payment securely"],
    [PackageCheck, "Curated marketplace", "Every artisan is reviewed"],
    [Truck, "Flexible delivery", "Courier, pickup and collection options"],
    [Heart, "Made with meaning", "Support independent local makers"],
  ] as const;
  return (
    <section className="border-y border-[#E7D4C2] bg-[#FFF9F2] py-8">
      <div className="mx-auto grid max-w-[1440px] gap-5 px-5 sm:grid-cols-2 sm:px-8 lg:grid-cols-4 lg:divide-x lg:divide-[#E7D4C2]">
        {items.map(([Icon, title, copy]) => <div key={title} className="flex items-center gap-3 lg:px-6 first:pl-0"><span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-[#7A0000]/12 via-[#D4A020]/12 to-[#559826]/12"><Icon className="size-4 text-artisan-terracotta" /></span><div><h3 className="font-sans text-xs font-bold">{title}</h3><p className="mt-0.5 text-[11px] text-muted-foreground">{copy}</p></div></div>)}
      </div>
    </section>
  );
}

function SellerInvitation() {
  return (
    <section className="bg-[radial-gradient(circle_at_78%_28%,rgba(212,160,32,0.10),transparent_24%),radial-gradient(circle_at_20%_80%,rgba(85,152,38,0.07),transparent_27%),#FFF9F2] px-5 py-20 sm:px-8 sm:py-28">
      <div className="mx-auto flex max-w-[1180px] flex-col items-start justify-between gap-8 border-y border-[#D9BFA9] py-12 md:flex-row md:items-center">
        <div className="max-w-2xl"><p className="text-[10px] font-bold uppercase tracking-[0.22em] text-artisan-terracotta">For South African makers</p><h2 className="mt-3 font-serif text-3xl font-bold leading-tight text-[#351711] sm:text-4xl">A beautiful place for work <span className="gradient-text italic">made with care.</span></h2><p className="mt-4 max-w-xl leading-7 text-muted-foreground">Open your own shopfront, meet new customers and grow alongside a community that values the handmade.</p></div>
        <div className="flex shrink-0 flex-col gap-3 sm:flex-row md:flex-col lg:flex-row"><Button asChild size="lg" className="rounded-full bg-[#8F120D] px-7"><Link href="/login?intent=vendor">Apply as an artisan <ArrowRight className="ml-2 size-4" /></Link></Button><Button asChild size="lg" variant="ghost" className="rounded-full text-[#60483B]"><Link href="/tutorials">How selling works</Link></Button></div>
      </div>
    </section>
  );
}

function Footer() {
  const businessRegistrationNumber =
    process.env.NEXT_PUBLIC_BUSINESS_REGISTRATION_NUMBER?.trim();
  return (
    <footer className="bg-[#24100C] py-14 text-[#F6EBDD]">
      <div className="mx-auto grid max-w-[1440px] gap-10 px-5 sm:px-8 md:grid-cols-[1.5fr_1fr_1fr_1fr]">
        <div>
          <Link href="/" className="flex items-center gap-3"><Image src="/logo.png" alt="" width={42} height={42} className="rounded-full" /><span className="font-serif text-xl font-bold">Artisan Lane</span></Link>
          <p className="mt-5 max-w-xs text-sm leading-6 text-[#D9BFA9]">A curated home for South African craftsmanship, independent makers and pieces with a story.</p>
          {businessRegistrationNumber ? <p className="mt-3 text-xs text-[#A98C78]">Company registration: {businessRegistrationNumber}</p> : null}
        </div>
        <div><h3 className="text-xs font-bold uppercase tracking-widest text-[#E5B35A]">Shop</h3><div className="mt-4 grid gap-3 text-sm text-[#D9BFA9]"><Link href="/shop">All products</Link><Link href="/shop?sort=newest">New arrivals</Link><Link href="/artisans">Artisans</Link><Link href="/account/favourites">Favourites</Link></div></div>
        <div><h3 className="text-xs font-bold uppercase tracking-widest text-[#E5B35A]">Artisan Lane</h3><div className="mt-4 grid gap-3 text-sm text-[#D9BFA9]"><Link href="/about">Our story</Link><Link href="/tutorials">Tutorials</Link><Link href="/login?intent=vendor">Become a seller</Link><Link href="mailto:nicky@artisanlanesa.com">Contact</Link></div></div>
        <div><h3 className="text-xs font-bold uppercase tracking-widest text-[#E5B35A]">Help</h3><div className="mt-4 grid gap-3 text-sm text-[#D9BFA9]"><Link href="/account/help">Help centre</Link><Link href="/terms">Terms</Link><Link href="/privacy">Privacy</Link><Link href="/login?intent=buyer">My account</Link></div></div>
      </div>
      <div className="mx-auto mt-12 flex max-w-[1440px] flex-col justify-between gap-3 border-t border-white/10 px-5 pt-6 text-xs text-[#A98C78] sm:flex-row sm:px-8"><span>© 2026 Artisan Lane. All rights reserved.</span><span>Made in South Africa</span></div>
    </footer>
  );
}

export default async function Home() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const [products, freshProducts, categories, favouriteIds] = await Promise.all([
    getFeaturedMarketplaceProducts(12),
    getFreshMarketplaceProducts(15),
    getMarketplaceCategories(),
    user ? listFavouriteProductIds(user.id) : Promise.resolve([]),
  ]);

  return (
    <main className="min-h-screen bg-[#FFF9F2]">
      <MarketplaceHeader activeItem="home" />
      <Hero products={products} />
      <CategoryRail categories={categories} products={products} />
      <ProductEdit products={freshProducts} favouriteIds={favouriteIds} />
      <MarketplaceStory products={products} />
      <TrustRow />
      <SellerInvitation />
      <Footer />
    </main>
  );
}
