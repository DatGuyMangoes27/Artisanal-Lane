import { Button } from "@/components/ui/button";
import type {
  VendorCategory,
  VendorProduct,
  VendorShop,
  VendorSubcategory,
} from "@/lib/marketplace/vendor-data";

const shippingMethods = [
  ["courier_guy", "Courier Guy Locker"],
  ["courier_guy_door_to_door", "Courier Guy Door to Door"],
  ["pargo", "Pargo Pickup"],
  ["market_pickup", "Market pickup"],
] as const;

function money(value: number | null | undefined) {
  return value == null ? "" : String(value);
}

function productVariantsJson(product?: VendorProduct | null) {
  if (!product?.variants.length) return "[]";
  return JSON.stringify(
    product.variants.map((variant) => ({
      displayName: variant.displayName,
      optionValues: variant.optionValues,
      price: variant.price,
      compareAtPrice: variant.compareAtPrice,
      stockQty: variant.stockQty,
      images: variant.images,
      isActive: variant.isActive,
      sortOrder: variant.sortOrder,
    })),
    null,
    2,
  );
}

export function VendorProductForm({
  action,
  product,
  shop,
  categories,
  subcategories,
  submitLabel,
}: {
  action: (formData: FormData) => void | Promise<void>;
  product?: VendorProduct | null;
  shop: VendorShop;
  categories: VendorCategory[];
  subcategories: VendorSubcategory[];
  submitLabel: string;
}) {
  const shippingOptions = product?.shippingOptions.length ? product.shippingOptions : shop.shippingOptions;

  return (
    <form action={action} className="grid gap-6">
      {product ? <input type="hidden" name="productId" value={product.id} /> : null}
      <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
        <h3 className="text-2xl font-semibold text-artisan-sienna">Core product details</h3>
        <div className="mt-5 grid gap-5 lg:grid-cols-2">
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
            Title
            <input name="title" required defaultValue={product?.title ?? ""} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm text-foreground" />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
            Description
            <textarea name="description" defaultValue={product?.description ?? ""} className="min-h-32 rounded-2xl border border-artisan-clay px-4 py-3 text-sm text-foreground" />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Category
            <select name="categoryId" defaultValue={product?.categoryId ?? ""} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm">
              <option value="">Select category</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>{category.name}</option>
              ))}
            </select>
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Subcategory
            <select name="subcategoryId" defaultValue={product?.subcategoryId ?? ""} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm">
              <option value="">Select subcategory</option>
              {subcategories.map((subcategory) => (
                <option key={subcategory.id} value={subcategory.id}>{subcategory.name}</option>
              ))}
            </select>
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Price
            <input name="price" required inputMode="decimal" defaultValue={money(product?.price)} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Compare-at price
            <input name="compareAtPrice" inputMode="decimal" defaultValue={money(product?.compareAtPrice)} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Stock quantity
            <input name="stockQty" inputMode="numeric" defaultValue={String(product?.stockQty ?? 0)} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          </label>
          <label className="flex items-center gap-3 text-sm font-medium text-artisan-sienna">
            <input name="isPublished" type="checkbox" defaultChecked={product?.isPublished ?? true} />
            Publish for buyers
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
            Tags
            <input name="tags" defaultValue={product?.tags.join(", ") ?? ""} placeholder="linen, ceramics, gift" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
            Care instructions
            <textarea name="careInstructions" defaultValue={product?.careInstructions ?? ""} className="min-h-24 rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          </label>
        </div>
      </section>

      <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
        <h3 className="text-2xl font-semibold text-artisan-sienna">Images</h3>
        <p className="mt-1 text-sm text-muted-foreground">Paste existing URLs, and upload any new product photos.</p>
        <div className="mt-5 grid gap-4">
          <textarea
            name="imageUrls"
            defaultValue={product?.images.join("\n") ?? ""}
            className="min-h-28 rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            placeholder="One hosted image URL per line"
          />
          <input name="productImages" type="file" accept="image/*" multiple className="text-sm" />
        </div>
      </section>

      <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
        <h3 className="text-2xl font-semibold text-artisan-sienna">Variants and options</h3>
        <p className="mt-1 text-sm text-muted-foreground">Use JSON for option groups and variant combinations, matching the mobile multi-option model.</p>
        <div className="mt-5 grid gap-4 lg:grid-cols-2">
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Option groups JSON
            <textarea name="optionGroupsJson" defaultValue={JSON.stringify(product?.optionGroups ?? [], null, 2)} className="min-h-48 rounded-2xl border border-artisan-clay px-4 py-3 font-mono text-xs" />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Variants JSON
            <textarea name="variantsJson" defaultValue={productVariantsJson(product)} className="min-h-48 rounded-2xl border border-artisan-clay px-4 py-3 font-mono text-xs" />
          </label>
        </div>
      </section>

      <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
        <h3 className="text-2xl font-semibold text-artisan-sienna">Shipping options</h3>
        <div className="mt-5 grid gap-4">
          {shippingMethods.map(([key, label]) => {
            const option = shippingOptions.find((item) => item.key === key);
            return (
              <div key={key} className="grid gap-3 rounded-2xl border border-artisan-clay/70 p-4 md:grid-cols-[1fr_10rem_1fr]">
                <label className="flex items-center gap-3 text-sm font-medium text-artisan-sienna">
                  <input name={`shipping_${key}`} type="checkbox" defaultChecked={option?.enabled ?? true} />
                  {label}
                </label>
                <input name={`shipping_price_${key}`} defaultValue={String(option?.price ?? 0)} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
                {key === "market_pickup" ? (
                  <div className="grid gap-2">
                    <input name={`shipping_market_name_${key}`} placeholder="Market name" defaultValue={option?.marketName ?? ""} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
                    <input name={`shipping_market_location_${key}`} placeholder="Market location" defaultValue={option?.marketLocation ?? ""} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
                    <input name={`shipping_market_province_${key}`} placeholder="Province" defaultValue={option?.marketProvince ?? ""} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      </section>

      <Button className="w-fit rounded-full bg-artisan-terracotta px-8 hover:bg-artisan-terracotta/90">
        {submitLabel}
      </Button>
    </form>
  );
}
