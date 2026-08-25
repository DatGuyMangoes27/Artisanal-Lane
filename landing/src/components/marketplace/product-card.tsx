import Image from "next/image";
import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ProductCardAddToCartButton } from "@/components/marketplace/product-card-add-to-cart-button";
import { ProductFavouriteButton } from "@/components/marketplace/product-favourite-button";
import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "@/lib/marketplace/format";
import type { MarketplaceProduct } from "@/lib/marketplace/types";

export function ProductCard({
  product,
  isFavourite = false,
  redirectTo = "/shop",
}: {
  product: MarketplaceProduct;
  isFavourite?: boolean;
  redirectTo?: string;
}) {
  const onSale = isProductOnSale(product);
  const mtoAvailable = product.fulfillmentMode === "made_to_order" ||
    (product.fulfillmentMode === "stocked_with_mto" && product.stockQty <= 0);

  return (
    <article className="group flex h-full min-w-0 flex-col">
      <div className="relative aspect-[4/5] overflow-hidden rounded-[1.35rem] bg-[#F1E4D7] shadow-[0_10px_30px_rgba(58,23,17,0.06)]">
        <Link href={`/products/${product.id}`} className="block size-full">
          <Image
            src={getProductPrimaryImage(product)}
            alt={product.title}
            fill
            sizes="(min-width: 1280px) 22vw, (min-width: 1024px) 25vw, (min-width: 640px) 50vw, 100vw"
            className="object-cover transition duration-700 ease-out group-hover:scale-[1.045]"
          />
        </Link>
        <div className="absolute left-3 top-3 flex flex-col gap-2">
          {onSale ? <Badge className="rounded-full bg-[#8F120D] px-3 py-1 text-[10px] uppercase tracking-widest text-white">Sale</Badge> : null}
          {mtoAvailable ? <Badge variant="secondary" className="rounded-full bg-white/90 px-3 py-1 text-[10px] uppercase tracking-wider backdrop-blur">Made to order</Badge> : null}
        </div>
        <div className="absolute right-3 top-3">
          <ProductFavouriteButton productId={product.id} initialIsFavourite={isFavourite} redirectTo={redirectTo} />
        </div>
      </div>

      <div className="flex flex-1 flex-col px-1 pb-1 pt-4">
        <Link href={`/shops/${product.shop?.slug ?? product.shop?.id ?? ""}`} className="mb-1.5 line-clamp-1 text-[10px] font-bold uppercase tracking-[0.17em] text-artisan-terracotta hover:underline">
          {product.shop?.name ?? "Artisan Lane seller"}
        </Link>
        <Link href={`/products/${product.id}`} className="line-clamp-2 min-h-12 font-serif text-[1.05rem] font-semibold leading-6 text-[#3A1711] transition group-hover:text-artisan-terracotta">
          {product.title}
        </Link>
        <div className="mt-2 flex items-end justify-between gap-3">
          <div className="flex flex-wrap items-baseline gap-2">
            <p className="font-bold text-[#3A1711]">{formatPrice(product.price)}</p>
            {onSale && product.compareAtPrice ? <p className="text-xs text-muted-foreground line-through">{formatPrice(product.compareAtPrice)}</p> : null}
          </div>
          <span className="shrink-0 text-[10px] font-medium text-muted-foreground">{mtoAvailable ? "Custom made" : getProductStockLabel(product)}</span>
        </div>
        <div className="mt-3 opacity-100 transition lg:translate-y-1 lg:opacity-0 lg:group-hover:translate-y-0 lg:group-hover:opacity-100 lg:group-focus-within:translate-y-0 lg:group-focus-within:opacity-100">
          {mtoAvailable ? (
            <Button asChild variant="outline" size="sm" className="w-full rounded-full border-artisan-terracotta/30 bg-white/70">
              <Link href={`/products/${product.id}`}>View options</Link>
            </Button>
          ) : <ProductCardAddToCartButton productId={product.id} disabled={product.stockQty <= 0} />}
        </div>
      </div>
    </article>
  );
}
