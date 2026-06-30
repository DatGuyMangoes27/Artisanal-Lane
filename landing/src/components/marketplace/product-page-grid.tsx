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
    <main className="mx-auto grid max-w-7xl gap-10 px-4 py-10 sm:px-6 lg:grid-cols-[1.05fr_0.95fr] lg:px-8 lg:py-14">
      <ProductGallery
        key={galleryKey}
        images={displayImages}
        title={product.title}
        onSale={onSale}
      />

      <section className="space-y-8">
        {header}

        <div className="rounded-3xl border border-artisan-clay bg-card p-6 shadow-sm">
          <ProductPurchasePanel
            product={product}
            openMtoUnits={openMtoUnits}
            onVariantChange={handleVariantChange}
          />
          {actions}
        </div>

        {footer}
      </section>
    </main>
  );
}
