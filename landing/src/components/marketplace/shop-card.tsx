import Link from "next/link";
import { MapPin } from "lucide-react";

import type { MarketplaceShopSummary } from "@/lib/marketplace/types";

export type ShopCardShop = MarketplaceShopSummary & {
  coverImageUrl?: string | null;
  productCount?: number;
};

function usableImageUrl(value: string | null | undefined) {
  const url = value?.trim();
  return url && /^https?:\/\//i.test(url) ? url : null;
}

export function shopProductCountLabel(count: number | undefined) {
  if (count === undefined) {
    return null;
  }

  if (count <= 0) {
    return "Setting up shop";
  }

  return `${count} ${count === 1 ? "piece" : "pieces"}`;
}

// Directory card styled after the app's shop cards: cover photo banner with
// the logo overlapping its bottom edge. Images use plain <img alt=""> on top
// of a branded gradient, so a missing or broken URL simply shows the gradient
// (browsers draw nothing for a failed decorative image) without client JS.
export function ShopCard({ shop }: { shop: ShopCardShop }) {
  const initial = shop.name.trim().charAt(0).toUpperCase() || "A";
  const coverUrl = usableImageUrl(shop.coverImageUrl);
  const logoUrl = usableImageUrl(shop.logoUrl);
  const countLabel = shopProductCountLabel(shop.productCount);

  return (
    <Link
      href={`/shops/${shop.slug || shop.id}`}
      aria-label={`Visit ${shop.name}`}
      data-testid="shop-card"
      className="group flex h-full flex-col overflow-hidden rounded-3xl border border-artisan-clay/80 bg-card shadow-sm transition hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-artisan-terracotta focus-visible:ring-offset-2"
    >
      <div
        className="relative aspect-[16/9] overflow-hidden bg-gradient-to-br from-artisan-terracotta via-artisan-sienna to-artisan-ochre"
        data-cover={coverUrl ? "image" : "fallback"}
      >
        <span
          aria-hidden="true"
          className="absolute -bottom-6 right-3 select-none font-serif text-[7rem] font-bold leading-none text-white/15"
        >
          {initial}
        </span>
        {coverUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={coverUrl}
            alt=""
            loading="lazy"
            decoding="async"
            className="absolute inset-0 size-full object-cover transition duration-500 group-hover:scale-105"
          />
        ) : null}
        <div className="absolute inset-0 bg-gradient-to-t from-black/30 via-transparent to-transparent" />
        {shop.isOffline ? (
          <span className="absolute right-3 top-3 rounded-full bg-black/60 px-2.5 py-1 text-[11px] font-semibold text-white">
            Away
          </span>
        ) : null}
      </div>

      <div className="relative flex flex-1 flex-col px-4 pb-4 pt-9 sm:px-5">
        <div className="absolute -top-8 left-4 size-16 overflow-hidden rounded-full border-4 border-card bg-gradient-to-br from-artisan-terracotta to-artisan-clay shadow-sm sm:left-5">
          <span
            aria-hidden="true"
            className="flex size-full items-center justify-center font-serif text-xl font-bold text-white"
          >
            {initial}
          </span>
          {logoUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={logoUrl}
              alt=""
              loading="lazy"
              decoding="async"
              className="absolute inset-0 size-full object-cover"
            />
          ) : null}
        </div>

        <h3 className="break-words font-serif text-lg font-bold leading-snug text-foreground [overflow-wrap:anywhere] group-hover:underline">
          {shop.name}
        </h3>
        <p className="mt-1 flex min-w-0 items-center gap-1.5 text-sm text-muted-foreground">
          <MapPin aria-hidden="true" className="size-3.5 shrink-0 text-artisan-terracotta" />
          <span className="truncate">{shop.location ?? "South Africa"}</span>
        </p>
        {countLabel ? (
          <p className="mt-3 text-xs font-semibold uppercase tracking-[0.16em] text-artisan-terracotta">
            {countLabel}
          </p>
        ) : null}
      </div>
    </Link>
  );
}
