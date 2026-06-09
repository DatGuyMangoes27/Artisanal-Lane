import Image from "next/image";
import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
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
  const mtoAvailable =
    product.fulfillmentMode === "made_to_order" ||
    (product.fulfillmentMode === "stocked_with_mto" && product.stockQty <= 0);

  return (
    <Card className="flex h-full flex-col overflow-hidden border-artisan-clay/80 bg-card/95 py-0">
      <div className="relative aspect-square overflow-hidden bg-secondary">
        <Link href={`/products/${product.id}`} className="group block size-full">
          <Image
            src={getProductPrimaryImage(product)}
            alt={product.title}
            fill
            sizes="(min-width: 1024px) 25vw, (min-width: 640px) 50vw, 100vw"
            className="object-cover transition duration-500 group-hover:scale-105"
          />
        </Link>
        {onSale ? <Badge className="absolute left-3 top-3 bg-artisan-terracotta">Sale</Badge> : null}
        <div className="absolute right-3 top-3">
          <ProductFavouriteButton
            productId={product.id}
            initialIsFavourite={isFavourite}
            redirectTo={redirectTo}
          />
        </div>
      </div>
      <CardContent className="flex flex-1 flex-col gap-3 p-4">
        <div className="min-h-[4.75rem]">
          <Link
            href={`/products/${product.id}`}
            className="line-clamp-2 font-semibold text-foreground hover:underline"
          >
            {product.title}
          </Link>
          <p className="mt-1 line-clamp-1 text-sm text-muted-foreground">
            {product.shop?.name ?? "Artisan Lane seller"}
          </p>
        </div>
        <div className="mt-auto flex min-h-10 items-end justify-between gap-3">
          <div>
            <p className="font-semibold text-foreground">{formatPrice(product.price)}</p>
            {onSale && product.compareAtPrice ? (
              <p className="text-sm text-muted-foreground line-through">{formatPrice(product.compareAtPrice)}</p>
            ) : null}
          </div>
          <span className="text-xs font-medium text-muted-foreground">
            {mtoAvailable ? "Made to order" : getProductStockLabel(product)}
          </span>
        </div>
        {mtoAvailable ? (
          <Button asChild variant="outline" size="sm" className="w-full rounded-full">
            <Link href={`/products/${product.id}`}>View options</Link>
          </Button>
        ) : (
          <ProductCardAddToCartButton productId={product.id} disabled={product.stockQty <= 0} />
        )}
      </CardContent>
    </Card>
  );
}
