"use client";

import { useState } from "react";
import type { ReactNode } from "react";

import type { MarketplaceProduct, MarketplaceVariant } from "@/lib/marketplace/types";

import { ProductGallery } from "./product-gallery";
import { ProductPurchasePanel } from "./product-purchase-panel";

type Props = {
  product: MarketplaceProduct;
  baseImages: string[];
  openMtoUnits: number;
  onSale: boolean;
  header: ReactNode;
  actions: ReactNode;
  footer: ReactNode;
};

export function ProductPageGrid({
  product,
  baseImages,
  openMtoUnits,
  onSale,
  header,
  actions,
  footer,
}: Props) {
  const [displayImages, setDisplayImages] = useState(baseImages);
  const [galleryKey, setGalleryKey] = useState("base");

  function handleVariantChange(variant: MarketplaceVariant | null) {
    const imgs = variant?.images?.length ? variant.images : baseImages;
    setDisplayImages(imgs);
    setGalleryKey(variant?.id ?? "base");
  }

  return (
    <main className="mx-auto max-w-[1440px] px-4 py-8 sm:px-6 lg:px-8 lg:py-12">
      <div className="grid gap-10 lg:grid-cols-[1.16fr_0.84fr] xl:gap-16">
        <ProductGallery key={galleryKey} images={displayImages} title={product.title} onSale={onSale} />

        <section className="lg:sticky lg:top-36 lg:self-start">
          <div className="space-y-7">
            {header}
            <div className="rounded-[1.5rem] border border-artisan-clay bg-white p-5 shadow-[0_18px_50px_rgba(58,23,17,0.07)] sm:p-6">
              <ProductPurchasePanel product={product} openMtoUnits={openMtoUnits} onVariantChange={handleVariantChange} />
              {actions}
            </div>
          </div>
        </section>
      </div>

      <section className="mt-14 border-t border-artisan-clay pt-12 lg:mt-20 lg:pt-16">
        {footer}
      </section>
    </main>
  );
}
