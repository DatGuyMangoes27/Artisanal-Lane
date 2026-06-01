import { notFound } from "next/navigation";

import { Button } from "@/components/ui/button";
import { VendorProductForm } from "@/components/vendor/vendor-product-form";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { deleteVendorProduct, updateVendorProduct } from "@/app/vendor/actions";
import {
  getVendorProduct,
  listVendorCategories,
  requireVendorShop,
} from "@/lib/marketplace/vendor-data";

export default async function EditVendorProductPage({
  params,
}: {
  params: Promise<{ productId: string }>;
}) {
  const { productId } = await params;
  const { shop } = await requireVendorShop(`/vendor/products/${productId}`);
  const [product, taxonomy] = await Promise.all([
    getVendorProduct(shop.id, productId),
    listVendorCategories(),
  ]);

  if (!product) {
    notFound();
  }

  return (
    <div>
      <VendorPageHeader
        eyebrow="Catalog"
        title={product.title}
        description="Update listing details, images, shipping options, publish state, and variant combinations."
      />
      <VendorProductForm
        action={updateVendorProduct}
        product={product}
        shop={shop}
        categories={taxonomy.categories}
        subcategories={taxonomy.subcategories}
        submitLabel="Save product"
      />
      <div className="mt-6">
        <VendorPanel title="Archive product" description="Archived products stay in order history but disappear from buyer-facing catalog pages.">
          <form action={deleteVendorProduct}>
            <input type="hidden" name="productId" value={product.id} />
            <Button type="submit" variant="destructive">Archive product</Button>
          </form>
        </VendorPanel>
      </div>
    </div>
  );
}
