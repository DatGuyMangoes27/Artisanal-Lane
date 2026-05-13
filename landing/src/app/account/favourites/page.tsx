import Link from "next/link";

import { toggleFavouriteProduct } from "@/app/account/actions";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ProductCard } from "@/components/marketplace/product-card";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { requireBuyerAccountSession } from "@/lib/marketplace/account";
import { listFavouriteProducts } from "@/lib/marketplace/buyer-preferences-data";

export default async function FavouritesPage() {
  const { user } = await requireBuyerAccountSession("/account/favourites");
  const products = await listFavouriteProducts(user.id);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
              Buyer account
            </p>
            <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
              Favourites
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        {products.length === 0 ? (
          <Card className="mt-10 border-artisan-clay bg-card text-center">
            <CardContent className="p-8">
              <h2 className="font-serif text-2xl font-bold text-foreground">No favourites yet</h2>
              <p className="mt-2 text-muted-foreground">Save products you want to find again later.</p>
              <Button asChild className="mt-6 rounded-full">
                <Link href="/shop">Browse products</Link>
              </Button>
            </CardContent>
          </Card>
        ) : (
          <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {products.map((product) => (
              <div key={product.id} className="space-y-3">
                <ProductCard product={product} />
                <form action={toggleFavouriteProduct}>
                  <input type="hidden" name="productId" value={product.id} />
                  <input type="hidden" name="action" value="remove" />
                  <input type="hidden" name="redirectTo" value="/account/favourites" />
                  <Button type="submit" variant="outline" className="w-full rounded-full">
                    Remove favourite
                  </Button>
                </form>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
