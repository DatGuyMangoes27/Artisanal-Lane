import { VendorProductForm } from "@/components/vendor/vendor-product-form";
import { VendorPageHeader } from "@/components/vendor/vendor-shell";
import { createVendorProduct } from "@/app/vendor/actions";
import { listVendorCategories, requireVendorShop } from "@/lib/marketplace/vendor-data";

export default async function NewVendorProductPage() {
  const { shop } = await requireVendorShop("/vendor/products/new");
  const { categories, subcategories } = await listVendorCategories();

  return (
    <div>
      <VendorPageHeader
        eyebrow="Catalog"
        title="Add product"
        description="Create a buyer-facing listing with images, tags, variants, care instructions, publish state, and shipping rules."
      />
      <VendorProductForm
        action={createVendorProduct}
        shop={shop}
        categories={categories}
        subcategories={subcategories}
        submitLabel="Create product"
      />
    </div>
  );
}
