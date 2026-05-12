import Image from "next/image";
import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  formatPrice,
  getProductPrimaryImage,
  getProductStockLabel,
  isProductOnSale,
} from "@/lib/marketplace/format";
import type { MarketplaceProduct } from "@/lib/marketplace/types";

export function ProductCard({ product }: { product: MarketplaceProduct }) {
  const onSale = isProductOnSale(product);

  return (
    <Card className="overflow-hidden border-artisan-clay/80 bg-card/95 py-0">
      <Link href={`/products/${product.id}`} className="group block">
        <div className="relative aspect-square overflow-hidden bg-secondary">
          <Image
            src={getProductPrimaryImage(product)}
            alt={product.title}
            fill
            sizes="(min-width: 1024px) 25vw, (min-width: 640px) 50vw, 100vw"
            className="object-cover transition duration-500 group-hover:scale-105"
          />
          {onSale ? <Badge className="absolute left-3 top-3 bg-artisan-terracotta">Sale</Badge> : null}
        </div>
      </Link>
      <CardContent className="space-y-3 p-4">
        <div>
          <Link href={`/products/${product.id}`} className="font-semibold text-foreground hover:underline">
            {product.title}
          </Link>
          <p className="mt-1 text-sm text-muted-foreground">{product.shop?.name ?? "Artisan Lane seller"}</p>
        </div>
        <div className="flex items-end justify-between gap-3">
          <div>
            <p className="font-semibold text-foreground">{formatPrice(product.price)}</p>
            {onSale && product.compareAtPrice ? (
              <p className="text-sm text-muted-foreground line-through">{formatPrice(product.compareAtPrice)}</p>
            ) : null}
          </div>
          <span className="text-xs font-medium text-muted-foreground">{getProductStockLabel(product)}</span>
        </div>
      </CardContent>
    </Card>
  );
}
