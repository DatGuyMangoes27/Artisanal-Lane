import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { AddToCartButton } from "@/components/marketplace/add-to-cart-button";
import { GuestCartProvider } from "@/components/marketplace/guest-cart-provider";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { getMarketplaceProduct } from "@/lib/marketplace/catalog";
import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "@/lib/marketplace/format";
import type { ShippingOption } from "@/lib/marketplace/types";

type ProductPageProps = {
  params: Promise<{
    productId: string;
  }>;
};

function formatShippingName(option: ShippingOption) {
  return option.key
    .split("_")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

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
  const product = await getMarketplaceProduct(productId);

  if (!product) {
    notFound();
  }

  const onSale = isProductOnSale(product);
  const images = product.images.length > 0 ? product.images : [getProductPrimaryImage(product)];
  const enabledShippingOptions = product.shippingOptions.filter((option) => option.enabled);
  const isOutOfStock = product.stockQty <= 0;

  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-background">
        <MarketplaceHeader />
        <main className="mx-auto grid max-w-7xl gap-10 px-4 py-10 sm:px-6 lg:grid-cols-[1.05fr_0.95fr] lg:px-8 lg:py-14">
          <section aria-label={`${product.title} image gallery`} className="space-y-4">
            <div className="relative aspect-square overflow-hidden rounded-[2rem] border border-artisan-clay bg-secondary shadow-sm">
              <Image
                src={getProductPrimaryImage(product)}
                alt={product.title}
                fill
                priority
                sizes="(min-width: 1024px) 50vw, 100vw"
                className="object-cover"
              />
              {onSale ? <Badge className="absolute left-4 top-4 bg-artisan-terracotta">Sale</Badge> : null}
            </div>
            <div className="grid grid-cols-4 gap-3">
              {images.slice(0, 4).map((image, index) => (
                <div
                  key={`${image}-${index}`}
                  className="relative aspect-square overflow-hidden rounded-2xl border border-artisan-clay bg-secondary"
                >
                  <Image
                    src={image}
                    alt={`${product.title} image ${index + 1}`}
                    fill
                    sizes="25vw"
                    className="object-cover"
                  />
                </div>
              ))}
            </div>
          </section>

          <section className="space-y-8">
            <div>
              <Link
                href="/shop#artisans"
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
                <Badge variant={isOutOfStock ? "secondary" : "outline"}>
                  {getProductStockLabel(product)}
                </Badge>
              </div>
            </div>

            <div className="rounded-3xl border border-artisan-clay bg-card p-6 shadow-sm">
              <AddToCartButton productId={product.id} disabled={isOutOfStock} />
              {isOutOfStock ? (
                <p className="mt-3 text-sm text-muted-foreground">
                  This piece is currently unavailable. Check back for restocks from the maker.
                </p>
              ) : (
                <p className="mt-3 text-sm text-muted-foreground">
                  Guest cart saves on this device while full checkout is prepared for Phase 2.
                </p>
              )}
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
                        <p className="font-semibold text-foreground">{formatShippingName(option)}</p>
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
          </section>
        </main>
      </div>
    </GuestCartProvider>
  );
}
