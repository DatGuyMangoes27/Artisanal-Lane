import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { toggleFavouriteProduct } from "@/app/account/actions";
import { submitProductReview } from "@/app/account/reviews/actions";
import { GuestCartProvider } from "@/components/marketplace/guest-cart-provider";
import { ProductPurchasePanel } from "@/components/marketplace/product-purchase-panel";
import { ProductGallery } from "@/components/marketplace/product-gallery";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { listFavouriteProductIds } from "@/lib/marketplace/buyer-preferences-data";
import { getMarketplaceProduct } from "@/lib/marketplace/catalog";
import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "@/lib/marketplace/format";
import { shippingMethodName } from "@/lib/marketplace/shipping";
import {
  getLatestEligibleProductReviewContext,
  getProductReviewOverview,
} from "@/lib/marketplace/review-data";
import { createClient } from "@/lib/supabase/server";

import { createBuyerThreadForShop } from "../../account/messages/actions";

type ProductPageProps = {
  params: Promise<{
    productId: string;
  }>;
};


export async function generateMetadata({ params }: ProductPageProps): Promise<Metadata> {
  const { productId } = await params;
  const product = await getMarketplaceProduct(productId);

  if (!product) {
    notFound();
  }

  return {
    title: `${product.title} | Artisan Lane`,
    description:
      product.description ??
      `Shop ${product.title} from ${product.shop?.name ?? "an Artisan Lane maker"}.`,
  };
}

export default async function ProductPage({ params }: ProductPageProps) {
  const { productId } = await params;
  const [product, reviewOverview] = await Promise.all([
    getMarketplaceProduct(productId),
    getProductReviewOverview(productId),
  ]);

  if (!product) {
    notFound();
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const canReview = user
    ? Boolean(await getLatestEligibleProductReviewContext(user.id, product.id))
    : false;
  const favouriteIds = user ? await listFavouriteProductIds(user.id) : [];
  const isFavourite = favouriteIds.includes(product.id);
  const myReview = user
    ? reviewOverview.reviews.find((review) => review.buyerId === user.id) ?? null
    : null;
  const onSale = isProductOnSale(product);
  const images = product.images.length > 0 ? product.images : [getProductPrimaryImage(product)];
  const enabledShippingOptions = product.shippingOptions.filter((option) => option.enabled);
  const isOutOfStock = product.stockQty <= 0;
  const mtoEnabled =
    product.fulfillmentMode === "made_to_order" ||
    product.fulfillmentMode === "stocked_with_mto";
  const mtoAvailable = mtoEnabled && (product.fulfillmentMode === "made_to_order" || isOutOfStock);

  let openMtoUnits = 0;
  if (mtoEnabled && product.madeToOrderCapacity != null) {
    const { data: openUnits } = await supabase.rpc("made_to_order_open_units", {
      product_id_input: product.id,
    });
    openMtoUnits = typeof openUnits === "number" ? openUnits : 0;
  }

  const showUnavailableNote = isOutOfStock && !mtoEnabled;

  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-background">
        <MarketplaceHeader />
        <main className="mx-auto grid max-w-7xl gap-10 px-4 py-10 sm:px-6 lg:grid-cols-[1.05fr_0.95fr] lg:px-8 lg:py-14">
          <ProductGallery images={images} title={product.title} onSale={onSale} />

          <section className="space-y-8">
            <div>
              <Link
                href={product.shop ? `/shops/${product.shop.slug || product.shop.id}` : "/artisans"}
                className="text-sm font-semibold uppercase tracking-[0.24em] text-artisan-terracotta hover:underline"
              >
                {product.shop?.name ?? "Artisan Lane seller"}
              </Link>
              <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
                {product.title}
              </h1>
              <div className="mt-5 flex flex-wrap items-center gap-3">
                <p className="text-3xl font-bold text-foreground">{formatPrice(product.price)}</p>
                {onSale && product.compareAtPrice ? (
                  <p className="text-lg text-muted-foreground line-through">
                    {formatPrice(product.compareAtPrice)}
                  </p>
                ) : null}
                <Badge variant={isOutOfStock && !mtoAvailable ? "secondary" : "outline"}>
                  {mtoAvailable ? "Made to order" : getProductStockLabel(product)}
                </Badge>
              </div>
            </div>

            <div className="rounded-3xl border border-artisan-clay bg-card p-6 shadow-sm">
              <ProductPurchasePanel product={product} openMtoUnits={openMtoUnits} />
              <form action={createBuyerThreadForShop} className="mt-3">
                <input type="hidden" name="shopId" value={product.shopId} />
                <input type="hidden" name="redirectTo" value={`/products/${product.id}`} />
                <button
                  type="submit"
                  className="h-12 w-full rounded-full border border-artisan-clay text-sm font-semibold text-foreground transition hover:border-artisan-terracotta hover:text-artisan-terracotta"
                >
                  Message seller
                </button>
              </form>
              <form action={toggleFavouriteProduct} className="mt-3">
                <input type="hidden" name="productId" value={product.id} />
                <input type="hidden" name="action" value={isFavourite ? "remove" : "add"} />
                <input type="hidden" name="redirectTo" value={`/products/${product.id}`} />
                <button
                  type="submit"
                  className="h-12 w-full rounded-full border border-artisan-clay text-sm font-semibold text-foreground transition hover:border-artisan-terracotta hover:text-artisan-terracotta"
                >
                  {isFavourite ? "Saved to favourites" : "Save to favourites"}
                </button>
              </form>
              {showUnavailableNote ? (
                <p className="mt-3 text-sm text-muted-foreground">
                  This piece is currently unavailable. Check back for restocks from the maker.
                </p>
              ) : null}
            </div>

            <div className="space-y-3">
              <h2 className="font-serif text-2xl font-bold text-foreground">About this piece</h2>
              <p className="leading-8 text-muted-foreground">
                {product.description ?? "This artisan has not added a detailed description yet."}
              </p>
            </div>

            <div className="space-y-3">
              <h2 className="font-serif text-2xl font-bold text-foreground">Shipping options</h2>
              {enabledShippingOptions.length > 0 ? (
                <div className="grid gap-3">
                  {enabledShippingOptions.map((option) => (
                    <div
                      key={option.key}
                      className="rounded-3xl border border-artisan-clay bg-card p-4 text-sm"
                    >
                      <div className="flex items-center justify-between gap-4">
                        <p className="font-semibold text-foreground">{shippingMethodName(option.key)}</p>
                        <p className="text-muted-foreground">
                          {option.price > 0 ? formatPrice(option.price) : "Included"}
                        </p>
                      </div>
                      {option.marketName || option.marketLocation || option.marketProvince ? (
                        <p className="mt-2 text-muted-foreground">
                          {[option.marketName, option.marketLocation, option.marketProvince]
                            .filter(Boolean)
                            .join(", ")}
                        </p>
                      ) : null}
                    </div>
                  ))}
                </div>
              ) : (
                <p className="rounded-3xl border border-artisan-clay bg-card p-4 text-sm text-muted-foreground">
                  Shipping details will be confirmed with the artisan in the next checkout phase.
                </p>
              )}
            </div>

            <div className="space-y-4">
              <div className="flex flex-wrap items-end justify-between gap-3">
                <div>
                  <h2 className="font-serif text-2xl font-bold text-foreground">Reviews</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {reviewOverview.summary.reviewCount > 0
                      ? `${reviewOverview.summary.averageRating.toFixed(1)} out of 5 from ${reviewOverview.summary.reviewCount} ${
                          reviewOverview.summary.reviewCount === 1 ? "review" : "reviews"
                        }`
                      : "No reviews yet"}
                  </p>
                </div>
              </div>

              {myReview || canReview ? (
                <form action={submitProductReview} className="rounded-3xl border border-artisan-clay bg-card p-5">
                  <input type="hidden" name="productId" value={product.id} />
                  <input type="hidden" name="redirectTo" value={`/products/${product.id}`} />
                  <label className="block text-sm font-medium text-foreground">
                    Rating
                    <select
                      name="rating"
                      defaultValue={myReview?.rating ?? 5}
                      className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                    >
                      {[5, 4, 3, 2, 1].map((rating) => (
                        <option key={rating} value={rating}>
                          {rating} star{rating === 1 ? "" : "s"}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label className="mt-4 block text-sm font-medium text-foreground">
                    Review
                    <textarea
                      name="reviewText"
                      defaultValue={myReview?.reviewText ?? ""}
                      rows={4}
                      className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                      placeholder="Tell other buyers what you loved."
                    />
                  </label>
                  <Button type="submit" className="mt-4 rounded-full">
                    {myReview ? "Update review" : "Submit review"}
                  </Button>
                </form>
              ) : user ? (
                <p className="rounded-3xl border border-artisan-clay bg-card p-4 text-sm text-muted-foreground">
                  Reviews unlock after a delivered or completed order.
                </p>
              ) : (
                <p className="rounded-3xl border border-artisan-clay bg-card p-4 text-sm text-muted-foreground">
                  Sign in after receiving your order to leave a review.
                </p>
              )}

              <div className="space-y-3">
                {reviewOverview.reviews.length === 0 ? (
                  <p className="rounded-3xl border border-artisan-clay bg-card p-4 text-sm text-muted-foreground">
                    Once buyers receive their orders, product reviews will appear here.
                  </p>
                ) : (
                  reviewOverview.reviews.slice(0, 6).map((review) => (
                    <div key={review.id} className="rounded-3xl border border-artisan-clay bg-card p-5">
                      <div className="flex items-center justify-between gap-4">
                        <p className="font-semibold text-foreground">
                          {review.buyerDisplayName ?? "Artisan Lane buyer"}
                        </p>
                        <p className="text-sm font-semibold text-artisan-terracotta">
                          {"★".repeat(review.rating)}
                        </p>
                      </div>
                      {review.reviewText ? (
                        <p className="mt-3 text-sm leading-6 text-muted-foreground">{review.reviewText}</p>
                      ) : null}
                      <p className="mt-3 text-xs text-muted-foreground">
                        {new Date(review.createdAt).toLocaleDateString("en-ZA", {
                          year: "numeric",
                          month: "long",
                          day: "numeric",
                        })}
                      </p>
                    </div>
                  ))
                )}
              </div>
            </div>
          </section>
        </main>
      </div>
    </GuestCartProvider>
  );
}
