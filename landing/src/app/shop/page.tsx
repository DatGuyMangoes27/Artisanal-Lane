import Image from "next/image";
import Link from "next/link";
import { Suspense } from "react";
import { ArrowRight, Search, Sparkles } from "lucide-react";

import { ProductCarousel } from "@/components/marketplace/product-carousel";
import { ProductCard } from "@/components/marketplace/product-card";
import { SearchControls } from "@/components/marketplace/search-controls";
import { ShopCampaignPopup } from "@/components/marketplace/shop-campaign-popup";
import { listFavouriteProductIds } from "@/lib/marketplace/buyer-preferences-data";
import { listCampaignOffers } from "@/lib/marketplace/campaign-data";
import {
  getFreshMarketplaceProductCount,
  getFreshMarketplaceProducts,
  getMarketplaceCategories,
  getMarketplaceProducts,
  getMarketplaceProductCount,
  getMarketplaceSubcategories,
  getMarketplaceShopCount,
  type MarketplaceAvailabilityFilter,
  type MarketplacePriceFilter,
  type MarketplaceProductSort,
} from "@/lib/marketplace/catalog";
import { createClient } from "@/lib/supabase/server";
import { getProductPrimaryImage } from "@/lib/marketplace/format";

type ShopSearchParams = {
  q?: string;
  category?: string;
  subcategory?: string;
  sort?: MarketplaceProductSort;
  price?: MarketplacePriceFilter;
  availability?: MarketplaceAvailabilityFilter;
  page?: string;
  perPage?: string;
  view?: "standard" | "compact";
};

type ShopPageProps = {
  searchParams?: Promise<ShopSearchParams>;
};

function parseShopPage(value: string | undefined) {
  const page = Number(value);
  return Number.isFinite(page) && page > 0 ? Math.trunc(page) : 1;
}

function parseProductsPerPage(value: string | undefined) {
  const parsed = Number(value);
  return [12, 24, 48].includes(parsed) ? parsed : 24;
}

function buildDisplayHref(params: ShopSearchParams | undefined, changes: { perPage?: number; view?: "standard" | "compact" }) {
  const nextParams = new URLSearchParams(
    Object.entries(params ?? {}).filter((entry): entry is [string, string] => typeof entry[1] === "string" && entry[1].length > 0),
  );
  nextParams.delete("page");
  if (changes.perPage) nextParams.set("perPage", String(changes.perPage));
  if (changes.view) nextParams.set("view", changes.view);
  return `/shop?${nextParams.toString()}#all-products`;
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
  return queryString
    ? `/shop?${queryString}#all-products`
    : "/shop#all-products";
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
  const productsPerPage = parseProductsPerPage(params?.perPage);
  const productView = params?.view === "compact" ? "compact" : "standard";
  const productOffset = (currentPage - 1) * productsPerPage;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const [categories, subcategories, products, freshProducts, freshCount, shopCount, productCount, favouriteIds, campaignOffers] = await Promise.all([
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
    getFreshMarketplaceProducts(15, 7, { categoryId, subcategoryId }),
    getFreshMarketplaceProductCount(),
    getMarketplaceShopCount(),
    getMarketplaceProductCount(),
    user ? listFavouriteProductIds(user.id) : Promise.resolve([]),
    listCampaignOffers(),
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
  const heroProducts = freshProducts.slice(0, 3);
  const primaryHeroProduct = heroProducts[0];
  const selectedCategory = categories.find((category) => category.id === categoryId);

  return (
    <main>
      <ShopCampaignPopup offers={campaignOffers} />
      <section className="relative overflow-hidden border-b border-[#E7D4C2] bg-[#F8EEE3]">
        <div className="pointer-events-none absolute -left-52 -top-48 size-[38rem] rounded-full bg-gradient-to-br from-[#7A0000]/15 via-[#D4A020]/10 to-transparent blur-[95px]" />
        <div className="pointer-events-none absolute -bottom-56 left-[26%] size-[34rem] rounded-full bg-gradient-to-tr from-[#559826]/10 via-[#D4A020]/8 to-transparent blur-[95px]" />
        <div className="relative mx-auto grid min-h-[540px] max-w-[1500px] lg:grid-cols-[0.88fr_1.12fr]">
          <div className="relative z-10 flex items-center px-5 py-16 sm:px-8 lg:px-14 xl:px-20">
            <div className="max-w-[36rem]">
              <p className="flex items-center gap-3 text-[10px] font-bold uppercase tracking-[0.24em] text-[#8F2415]"><span className="flex size-8 items-center justify-center rounded-full bg-gradient-to-br from-[#7A0000]/15 via-[#D4A020]/15 to-[#559826]/15"><Sparkles className="size-4" /></span>The handmade collection</p>
              <h1 className="mt-5 font-serif text-[3.6rem] font-bold leading-[0.92] tracking-[-0.05em] text-[#351711] sm:text-7xl xl:text-[5rem]">Find the piece<br /><span className="gradient-text italic">no one else has.</span></h1>
              <p className="mt-6 max-w-lg text-base leading-7 text-[#6B5040] sm:text-lg">One marketplace, hundreds of pieces, each made by an independent South African artisan.</p>

              <form action="/shop" className="relative mt-8 max-w-lg">
                <label htmlFor="shop-hero-search" className="sr-only">Search the marketplace</label>
                <Search className="absolute left-5 top-1/2 size-5 -translate-y-1/2 text-[#806756]" />
                <input id="shop-hero-search" name="q" defaultValue={query} placeholder="Search handmade" className="h-15 w-full rounded-full border border-[#D8BEA7] bg-white/90 pl-13 pr-32 text-sm text-[#351711] shadow-[0_16px_40px_rgba(78,38,25,0.09)] outline-none placeholder:text-[#9A7F6C] focus:border-[#A6432B] focus:ring-4 focus:ring-[#A6432B]/10" />
                <button className="absolute right-1.5 top-1.5 h-12 rounded-full bg-gradient-to-r from-[#7A0000] via-[#9A2C12] to-[#8B4513] px-6 text-sm font-bold text-white transition hover:brightness-95">Search</button>
              </form>

              <p className="mt-6 text-xs text-[#8B6C59]"><strong className="text-[#351711]">{productCount}</strong> handmade pieces from <strong className="text-[#351711]">{shopCount}</strong> artisan shops</p>
            </div>
          </div>

          <div className="relative min-h-[430px] overflow-hidden lg:min-h-full">
            {primaryHeroProduct ? <Image src={getProductPrimaryImage(primaryHeroProduct)} alt={primaryHeroProduct.title} fill priority sizes="(min-width: 1024px) 56vw, 100vw" className="object-cover" /> : null}
            <div className="absolute inset-0 bg-gradient-to-r from-[#351711]/10 via-transparent to-transparent" />
            <div className="absolute inset-0 bg-gradient-to-t from-[#24100C]/65 via-transparent to-transparent" />
            {primaryHeroProduct ? (
              <Link href={`/products/${primaryHeroProduct.id}`} className="group absolute inset-x-5 bottom-5 flex items-end justify-between gap-5 border-l border-white/60 pl-5 text-white sm:inset-x-auto sm:bottom-8 sm:left-8 sm:max-w-[440px]">
                <span><span className="text-[9px] font-bold uppercase tracking-[0.2em] text-[#F0D18F]">New from {primaryHeroProduct.shop?.name}</span><span className="mt-1 block font-serif text-2xl font-bold leading-tight sm:text-3xl">{primaryHeroProduct.title}</span></span>
                <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-white text-[#351711] shadow-lg transition group-hover:translate-x-1"><ArrowRight className="size-4" /></span>
              </Link>
            ) : null}
          </div>
        </div>
      </section>

      <section className="border-b border-artisan-clay bg-[linear-gradient(90deg,#F7EBDD_0%,#FFF9F2_52%,#F0F3E6_100%)]">
        <div className="mx-auto flex max-w-[1500px] flex-col gap-4 px-4 py-6 sm:px-7 lg:flex-row lg:items-center">
          <div className="shrink-0"><p className="text-[9px] font-black uppercase tracking-[0.2em] text-[#A66A49]">Choose a department</p><p className="mt-1 font-serif text-lg font-bold text-[#351711]">Browse your way</p></div>
          <div className="flex gap-2 overflow-x-auto pb-1 lg:ml-6">
            <Link href="/shop" className={`shrink-0 rounded-full px-4 py-2 text-xs font-bold transition ${!categoryId ? "bg-[#351711] text-white" : "border border-[#DCC3AB] bg-white text-[#60483B] hover:border-[#8F120D]"}`}>Everything</Link>
            {categories.slice(0, 9).map((category) => <Link key={category.id} href={`/shop?category=${encodeURIComponent(category.id)}`} className={`shrink-0 rounded-full px-4 py-2 text-xs font-bold transition ${category.id === categoryId ? "bg-[#8F120D] text-white" : "border border-[#DCC3AB] bg-white text-[#60483B] hover:border-[#8F120D] hover:text-[#8F120D]"}`}>{category.name === "Home" ? "Home & Living" : category.name}</Link>)}
          </div>
        </div>
      </section>

      <section id="new-this-week" className="mx-auto max-w-[1440px] scroll-mt-36 px-4 py-16 sm:px-6 sm:py-20 lg:px-8">
        <div className="mb-6">
          <p className="text-[10px] font-bold uppercase tracking-[0.24em] text-artisan-terracotta">{selectedCategory ? `New in ${selectedCategory.name === "Home" ? "Home & Living" : selectedCategory.name}` : "Added in the last seven days"}</p>
          <div className="mt-2 flex flex-col justify-between gap-3 sm:flex-row sm:items-end"><div><h2 className="font-serif text-3xl font-bold text-[#351711] sm:text-4xl">The newest <span className="gradient-text italic">handmade finds</span></h2><p className="mt-2 text-sm text-muted-foreground">A live edit of the latest pieces published by our makers.</p></div><span className="w-fit rounded-full bg-[linear-gradient(135deg,rgba(122,0,0,0.08),rgba(212,160,32,0.12),rgba(85,152,38,0.08))] px-4 py-2 text-xs font-bold text-[#8F120D]">{freshCount} new this week</span></div>
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

      <section className="mx-auto max-w-[1440px] px-4 pb-5 pt-8 sm:px-6 lg:px-8">
        <Suspense fallback={<SearchControlsFallback />}>
          <SearchControls categories={categories} subcategories={subcategories} />
        </Suspense>
      </section>

      <section
        id="all-products"
        className="mx-auto max-w-[1440px] scroll-mt-36 px-4 py-10 sm:px-6 lg:px-8"
      >
        <div className="mb-6 flex flex-col justify-between gap-5 lg:flex-row lg:items-end">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta">
              All products
            </p>
            <h2 className="mt-2 font-serif text-3xl font-bold text-[#351711]">Explore the collection</h2>
          </div>
          <div className="flex flex-wrap items-center gap-4 text-xs text-muted-foreground">
            <span>Page {currentPage}</span>
            <div className="flex items-center gap-1 rounded-full border border-artisan-clay bg-white p-1">
              <span className="px-2">Show</span>
              {[12, 24, 48].map((amount) => <Link key={amount} href={buildDisplayHref(params, { perPage: amount })} className={`rounded-full px-3 py-1.5 font-semibold transition ${productsPerPage === amount ? "bg-[#351711] text-white" : "hover:bg-secondary"}`}>{amount}</Link>)}
            </div>
            <div className="flex items-center gap-1 rounded-full border border-artisan-clay bg-white p-1">
              <Link href={buildDisplayHref(params, { view: "standard" })} className={`rounded-full px-3 py-1.5 font-semibold transition ${productView === "standard" ? "bg-[#351711] text-white" : "hover:bg-secondary"}`}>Comfortable</Link>
              <Link href={buildDisplayHref(params, { view: "compact" })} className={`rounded-full px-3 py-1.5 font-semibold transition ${productView === "compact" ? "bg-[#351711] text-white" : "hover:bg-secondary"}`}>Compact</Link>
            </div>
          </div>
        </div>
        {pageProducts.length > 0 ? (
          <>
          <div className={`grid gap-x-4 gap-y-9 sm:grid-cols-2 md:grid-cols-3 ${productView === "compact" ? "xl:grid-cols-5" : "lg:grid-cols-4"}`}>
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
