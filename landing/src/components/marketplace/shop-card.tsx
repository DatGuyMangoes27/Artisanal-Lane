import Image from "next/image";
import Link from "next/link";

import { Card, CardContent } from "@/components/ui/card";
import type { MarketplaceShopSummary } from "@/lib/marketplace/types";

export function ShopCard({ shop }: { shop: MarketplaceShopSummary }) {
  const initial = shop.name.trim().charAt(0).toUpperCase() || "A";

  return (
    <Card className="border-artisan-clay/80 bg-card/95">
      <CardContent className="flex items-center gap-4 p-4">
        <div className="relative size-14 overflow-hidden rounded-full bg-secondary">
          {shop.logoUrl ? (
            <Image
              src={shop.logoUrl}
              alt={shop.name}
              fill
              sizes="56px"
              className="object-cover"
            />
          ) : (
            <div className="flex size-full items-center justify-center bg-gradient-to-br from-artisan-terracotta to-artisan-clay font-serif text-lg font-bold text-white">
              {initial}
            </div>
          )}
        </div>
        <div className="min-w-0 flex-1">
          <Link href={`/shops/${shop.slug || shop.id}`} className="font-semibold hover:underline">
            {shop.name}
          </Link>
          <p className="truncate text-sm text-muted-foreground">{shop.location ?? "South Africa"}</p>
        </div>
      </CardContent>
    </Card>
  );
}
