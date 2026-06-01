import Image from "next/image";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel, VendorSetupRequired } from "@/components/vendor/vendor-shell";
import { getVendorShop, listVendorProducts, requireVendorSession } from "@/lib/marketplace/vendor-data";
import { formatPrice } from "@/lib/marketplace/format";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

export default async function VendorProductsPage() {
  const { user } = await requireVendorSession("/vendor/products");
  const shop = await getVendorShop(user.id);

  if (!shop) {
    return (
      <div>
        <VendorPageHeader
          eyebrow="Catalog"
          title="Products"
          description="Create, edit, publish, archive, and manage variants for buyer-facing listings."
        />
        <VendorSetupRequired title="Create your shop before adding products" />
      </div>
    );
  }

  const products = await listVendorProducts(shop.id);

  return (
    <div>
      <VendorPageHeader
        eyebrow="Catalog"
        title="Products"
        description="Create, edit, publish, archive, and manage variants for the items buyers see in the marketplace."
        actions={
          <Button asChild className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
            <Link href="/vendor/products/new">Add product</Link>
          </Button>
        }
      />

      <VendorPanel title="Your catalog">
        {products.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-artisan-clay p-8 text-sm text-muted-foreground">
            No products yet. Add your first product once your payout details and subscription are ready.
          </div>
        ) : null}
        <div className="grid gap-4">
          {products.map((product) => (
            <Link
              key={product.id}
              href={`/vendor/products/${product.id}`}
              className="grid gap-4 rounded-3xl border border-artisan-clay/70 p-4 transition hover:bg-artisan-bone/40 md:grid-cols-[6rem_1fr_auto]"
            >
              <div className="relative h-24 w-24 overflow-hidden rounded-2xl bg-artisan-bone">
                {product.images[0] ? (
                  <Image src={product.images[0]} alt={product.title} fill className="object-cover" />
                ) : null}
              </div>
              <div>
                <p className="text-lg font-semibold text-artisan-sienna">{product.title}</p>
                <p className="mt-1 text-sm text-muted-foreground">
                  {product.categoryName ?? "Uncategorised"} · {product.stockQty} in stock ·{" "}
                  {product.variants.length} variants
                </p>
                <p className="mt-2 text-sm text-muted-foreground line-clamp-2">
                  {product.description ?? "No description added."}
                </p>
              </div>
              <div className="text-right text-sm">
                <p className="font-semibold text-artisan-sienna">{formatPrice(product.price)}</p>
                <p className={product.isPublished ? "text-green-700" : "text-amber-700"}>
                  {formatVendorStatus(product.isPublished ? "published" : "draft")}
                </p>
              </div>
            </Link>
          ))}
        </div>
      </VendorPanel>
    </div>
  );
}
