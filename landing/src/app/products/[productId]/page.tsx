import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight, Heart, MessageCircle, ShieldCheck, Star, Store, Truck } from "lucide-react";

import { toggleFavouriteProduct } from "@/app/account/actions";
import { submitProductReview } from "@/app/account/reviews/actions";
import { GuestCartProvider } from "@/components/marketplace/guest-cart-provider";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ProductCard } from "@/components/marketplace/product-card";
import { ProductPageGrid } from "@/components/marketplace/product-page-grid";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { listFavouriteProductIds } from "@/lib/marketplace/buyer-preferences-data";
import { getMarketplaceProduct, getMarketplaceProducts } from "@/lib/marketplace/catalog";
import { formatPrice, getProductPrimaryImage, getProductStockLabel, isProductOnSale } from "@/lib/marketplace/format";
import { getLatestEligibleProductReviewContext, getProductReviewOverview } from "@/lib/marketplace/review-data";
import { shippingMethodName } from "@/lib/marketplace/shipping";
import { createClient } from "@/lib/supabase/server";

import { createBuyerThreadForShop } from "../../account/messages/actions";

type ProductPageProps = { params: Promise<{ productId: string }> };

export async function generateMetadata({ params }: ProductPageProps): Promise<Metadata> {
  const { productId } = await params;
  const product = await getMarketplaceProduct(productId);
  if (!product) notFound();
  return {
    title: `${product.title} | Artisan Lane`,
    description: product.description ?? `Shop ${product.title} from ${product.shop?.name ?? "an Artisan Lane maker"}.`,
  };
}

export default async function ProductPage({ params }: ProductPageProps) {
  const { productId } = await params;
  const [product, reviewOverview] = await Promise.all([
    getMarketplaceProduct(productId),
    getProductReviewOverview(productId),
  ]);
  if (!product) notFound();

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const [canReview, favouriteIds, relatedCandidates] = await Promise.all([
    user ? getLatestEligibleProductReviewContext(user.id, product.id).then(Boolean) : Promise.resolve(false),
    user ? listFavouriteProductIds(user.id) : Promise.resolve([]),
    getMarketplaceProducts({ categoryId: product.category?.id, sort: "newest", limit: 9 }),
  ]);
  const relatedProducts = relatedCandidates.filter((item) => item.id !== product.id).slice(0, 4);
  const favouriteSet = new Set(favouriteIds);
  const isFavourite = favouriteSet.has(product.id);
  const myReview = user ? reviewOverview.reviews.find((review) => review.buyerId === user.id) ?? null : null;
  const onSale = isProductOnSale(product);
  const images = product.images.length > 0 ? product.images : [getProductPrimaryImage(product)];
  const enabledShippingOptions = product.shippingOptions.filter((option) => option.enabled);
  const isOutOfStock = product.stockQty <= 0;
  const mtoEnabled = product.fulfillmentMode === "made_to_order" || product.fulfillmentMode === "stocked_with_mto";
  const mtoAvailable = mtoEnabled && (product.fulfillmentMode === "made_to_order" || isOutOfStock);

  let openMtoUnits = 0;
  if (mtoEnabled && product.madeToOrderCapacity != null) {
    const { data: openUnits } = await supabase.rpc("made_to_order_open_units", { product_id_input: product.id });
    openMtoUnits = typeof openUnits === "number" ? openUnits : 0;
  }

  const shopHref = product.shop ? `/shops/${product.shop.slug || product.shop.id}` : "/artisans";

  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-[#FFF9F2]">
        <MarketplaceHeader />
        <div className="mx-auto max-w-[1440px] px-4 pt-6 text-xs text-muted-foreground sm:px-6 lg:px-8">
          <Link href="/shop" className="hover:text-artisan-terracotta">Shop</Link>
          <span className="mx-2">/</span>
          {product.category ? <><Link href={`/shop?category=${product.category.id}`} className="hover:text-artisan-terracotta">{product.category.name}</Link><span className="mx-2">/</span></> : null}
          <span className="line-clamp-1 inline text-foreground">{product.title}</span>
        </div>

        <ProductPageGrid
          product={product}
          baseImages={images}
          openMtoUnits={openMtoUnits}
          onSale={onSale}
          header={
            <div>
              <Link href={shopHref} className="text-[11px] font-bold uppercase tracking-[0.2em] text-artisan-terracotta hover:underline">Made by {product.shop?.name ?? "an Artisan Lane maker"}</Link>
              <h1 className="mt-3 font-serif text-4xl font-bold leading-[1.05] tracking-tight text-[#351711] md:text-5xl">{product.title}</h1>
              <div className="mt-4 flex flex-wrap items-center gap-3 text-sm">
                <span className="flex items-center gap-1 font-semibold text-[#6B5040]"><Star className="size-4 fill-[#D4A020] text-[#D4A020]" />{reviewOverview.summary.reviewCount ? reviewOverview.summary.averageRating.toFixed(1) : "New"}</span>
                <span className="text-muted-foreground">{reviewOverview.summary.reviewCount} {reviewOverview.summary.reviewCount === 1 ? "review" : "reviews"}</span>
                <span className="text-artisan-clay">•</span>
                <Link href={shopHref} className="font-medium text-muted-foreground hover:text-artisan-terracotta">Visit the shop</Link>
              </div>
              <div className="mt-6 flex flex-wrap items-center gap-3">
                <p className="text-3xl font-bold text-[#351711]">{formatPrice(product.price)}</p>
                {onSale && product.compareAtPrice ? <p className="text-lg text-muted-foreground line-through">{formatPrice(product.compareAtPrice)}</p> : null}
                <Badge className="rounded-full bg-[#F2E4D7] text-[#6B2A20]" variant="secondary">{mtoAvailable ? "Made to order" : getProductStockLabel(product)}</Badge>
              </div>
            </div>
          }
          actions={
            <div className="mt-3 grid grid-cols-2 gap-3">
              <form action={createBuyerThreadForShop}>
                <input type="hidden" name="shopId" value={product.shopId} />
                <input type="hidden" name="redirectTo" value={`/products/${product.id}`} />
                <button type="submit" className="flex h-11 w-full items-center justify-center gap-2 rounded-full border border-artisan-clay text-xs font-semibold transition hover:border-artisan-terracotta hover:text-artisan-terracotta"><MessageCircle className="size-4" /> Message maker</button>
              </form>
              <form action={toggleFavouriteProduct}>
                <input type="hidden" name="productId" value={product.id} />
                <input type="hidden" name="action" value={isFavourite ? "remove" : "add"} />
                <input type="hidden" name="redirectTo" value={`/products/${product.id}`} />
                <button type="submit" className="flex h-11 w-full items-center justify-center gap-2 rounded-full border border-artisan-clay text-xs font-semibold transition hover:border-artisan-terracotta hover:text-artisan-terracotta"><Heart className={`size-4 ${isFavourite ? "fill-artisan-terracotta text-artisan-terracotta" : ""}`} /> {isFavourite ? "Saved" : "Save"}</button>
              </form>
            </div>
          }
          footer={
            <div className="grid gap-12 lg:grid-cols-[1.15fr_0.85fr]">
              <div>
                <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-artisan-terracotta">The details</p>
                <h2 className="mt-2 font-serif text-3xl font-bold text-[#351711]">About this piece</h2>
                <p className="mt-5 whitespace-pre-line text-base leading-8 text-muted-foreground">{product.description ?? "This artisan has not added a detailed description yet."}</p>
                {product.fragranceDescription ? <div className="mt-8 rounded-2xl bg-[#F6EBDD] p-5"><h3 className="font-serif text-xl font-bold">Fragrance options</h3><p className="mt-2 leading-7 text-muted-foreground">{product.fragranceDescription}</p></div> : null}

                <div className="mt-10 rounded-[1.5rem] border border-artisan-clay bg-white p-6">
                  <div className="flex items-start gap-4"><span className="flex size-12 shrink-0 items-center justify-center rounded-full bg-[#F6EBDD] text-artisan-terracotta"><Store /></span><div><p className="text-xs font-bold uppercase tracking-widest text-artisan-terracotta">The maker</p><h3 className="mt-1 font-serif text-2xl font-bold">{product.shop?.name ?? "Artisan Lane seller"}</h3><p className="mt-1 text-sm text-muted-foreground">{product.shop?.location ?? "South Africa"}</p></div></div>
                  <Button asChild variant="outline" className="mt-5 w-full rounded-full"><Link href={shopHref}>Explore this artisan’s shop <ArrowRight className="ml-2 size-4" /></Link></Button>
                </div>
              </div>

              <div className="space-y-5">
                <div className="rounded-[1.5rem] border border-artisan-clay bg-white p-6">
                  <div className="flex items-center gap-3"><Truck className="text-artisan-terracotta" /><h2 className="font-serif text-2xl font-bold">Delivery options</h2></div>
                  {enabledShippingOptions.length > 0 ? <div className="mt-5 divide-y divide-artisan-clay">{enabledShippingOptions.map((option) => <div key={option.key} className="flex items-start justify-between gap-4 py-4 first:pt-0 last:pb-0"><div><p className="text-sm font-bold">{shippingMethodName(option.key)}</p>{option.marketName || option.marketLocation ? <p className="mt-1 text-xs text-muted-foreground">{[option.marketName, option.marketLocation, option.marketProvince].filter(Boolean).join(", ")}</p> : null}</div><p className="shrink-0 text-sm font-semibold">{option.price > 0 ? formatPrice(option.price) : "Included"}</p></div>)}</div> : <p className="mt-4 text-sm leading-6 text-muted-foreground">Delivery details are confirmed during checkout.</p>}
                </div>
                <div className="rounded-[1.5rem] bg-[#351711] p-6 text-[#FFF8F0]"><ShieldCheck className="size-7 text-[#E5B35A]" /><h3 className="mt-4 font-serif text-2xl font-bold">Shop with confidence</h3><p className="mt-2 text-sm leading-6 text-[#D9BFA9]">TradeSafe protects your payment while order updates keep you informed from purchase to delivery.</p></div>
              </div>

              <div className="lg:col-span-2 lg:mt-4">
                <div className="flex flex-wrap items-end justify-between gap-3"><div><p className="text-[11px] font-bold uppercase tracking-[0.2em] text-artisan-terracotta">Buyer feedback</p><h2 className="mt-2 font-serif text-3xl font-bold text-[#351711]">Reviews</h2></div><p className="text-sm text-muted-foreground">{reviewOverview.summary.reviewCount ? `${reviewOverview.summary.averageRating.toFixed(1)} from ${reviewOverview.summary.reviewCount} verified ${reviewOverview.summary.reviewCount === 1 ? "review" : "reviews"}` : "Be the first to review this piece"}</p></div>

                {myReview || canReview ? <form action={submitProductReview} className="mt-6 grid gap-4 rounded-2xl border border-artisan-clay bg-white p-5 sm:grid-cols-[160px_1fr_auto] sm:items-end"><input type="hidden" name="productId" value={product.id} /><input type="hidden" name="redirectTo" value={`/products/${product.id}`} /><label className="text-sm font-medium">Rating<select name="rating" defaultValue={myReview?.rating ?? 5} className="mt-2 h-11 w-full rounded-xl border border-artisan-clay bg-[#FFF9F2] px-3">{[5,4,3,2,1].map((rating) => <option key={rating} value={rating}>{rating} stars</option>)}</select></label><label className="text-sm font-medium">Your review<textarea name="reviewText" defaultValue={myReview?.reviewText ?? ""} rows={2} className="mt-2 w-full rounded-xl border border-artisan-clay bg-[#FFF9F2] px-3 py-2" placeholder="What did you love?" /></label><Button type="submit" className="rounded-full">{myReview ? "Update" : "Submit"}</Button></form> : null}

                <div className="mt-6 grid gap-4 md:grid-cols-2">{reviewOverview.reviews.length ? reviewOverview.reviews.slice(0, 6).map((review) => <article key={review.id} className="rounded-2xl border border-artisan-clay bg-white p-5"><div className="flex items-center justify-between gap-3"><p className="font-bold">{review.buyerDisplayName ?? "Artisan Lane buyer"}</p><p className="text-sm text-[#D4A020]">{"★".repeat(review.rating)}</p></div>{review.reviewText ? <p className="mt-3 text-sm leading-6 text-muted-foreground">{review.reviewText}</p> : null}<p className="mt-3 text-xs text-muted-foreground">{new Date(review.createdAt).toLocaleDateString("en-ZA", {year:"numeric",month:"long",day:"numeric"})}</p></article>) : <p className="rounded-2xl border border-artisan-clay bg-white p-5 text-sm text-muted-foreground md:col-span-2">Reviews from verified buyers will appear here after delivery.</p>}</div>
              </div>
            </div>
          }
        />

        {relatedProducts.length ? <section className="border-t border-artisan-clay bg-white py-16"><div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8"><div className="mb-8 flex items-end justify-between"><div><p className="text-[11px] font-bold uppercase tracking-[0.2em] text-artisan-terracotta">Keep exploring</p><h2 className="mt-2 font-serif text-3xl font-bold text-[#351711]">You may also like</h2></div><Link href={product.category ? `/shop?category=${product.category.id}` : "/shop"} className="hidden text-sm font-semibold text-artisan-terracotta sm:block">View category →</Link></div><div className="grid grid-cols-2 gap-4 md:grid-cols-4 lg:gap-6">{relatedProducts.map((item) => <ProductCard key={item.id} product={item} isFavourite={favouriteSet.has(item.id)} redirectTo={`/products/${product.id}`} />)}</div></div></section> : null}
      </div>
    </GuestCartProvider>
  );
}
