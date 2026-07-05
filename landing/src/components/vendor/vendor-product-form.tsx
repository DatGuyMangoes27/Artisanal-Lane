import { Button } from "@/components/ui/button";
import { CategorySubcategoryFields } from "@/components/vendor/category-subcategory-fields";
import { ProductImagePicker } from "@/components/vendor/product-image-picker";
import { VariantOptionsEditor } from "@/components/vendor/variant-options-editor";
import type {
  VendorCategory,
  VendorProduct,
  VendorShop,
  VendorSubcategory,
} from "@/lib/marketplace/vendor-data";
import {
  SHIPPING_METHOD_KEYS,
  defaultShippingPrice,
  shippingMethodName,
} from "@/lib/marketplace/shipping";

const shippingMethods = SHIPPING_METHOD_KEYS.map(
  (key) => [key, shippingMethodName(key)] as const,
);

function money(value: number | null | undefined) {
  return value == null ? "" : String(value);
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
          <CategorySubcategoryFields
            categories={categories}
            subcategories={subcategories}
            defaultCategoryId={product?.categoryId}
            defaultSubcategoryId={product?.subcategoryId}
          />
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
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
            Fragrance options
            <textarea
              name="fragranceDescription"
              defaultValue={product?.fragranceDescription ?? ""}
              placeholder="e.g. Lavender & chamomile, vanilla bean, rooibos — describe the fragrances buyers can choose from"
              className="min-h-24 rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            />
            <span className="text-xs font-normal text-muted-foreground">
              Optional — for scented products like candles, soaps, and creams. Shown on the product page.
            </span>
          </label>
        </div>
      </section>

      <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
        <h3 className="text-2xl font-semibold text-artisan-sienna">Fulfillment</h3>
        <p className="mt-1 text-sm text-muted-foreground">
          Sell from stock, offer made-to-order custom pieces, or both. Made-to-order items stay buyable even when stock runs out.
        </p>
        <div className="mt-5 grid gap-5 lg:grid-cols-2">
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
            Fulfillment mode
            <select
              name="fulfillmentMode"
              defaultValue={product?.fulfillmentMode ?? "stocked"}
              className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            >
              <option value="stocked">Stocked only</option>
              <option value="made_to_order">Made to order only</option>
              <option value="stocked_with_mto">Stocked, then made to order when sold out</option>
            </select>
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Made-to-order price (optional)
            <input
              name="madeToOrderPrice"
              inputMode="decimal"
              defaultValue={money(product?.madeToOrderPrice)}
              placeholder="Defaults to the price above"
              className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Open made-to-order capacity (optional)
            <input
              name="madeToOrderCapacity"
              inputMode="numeric"
              defaultValue={product?.madeToOrderCapacity == null ? "" : String(product.madeToOrderCapacity)}
              placeholder="Leave blank for unlimited"
              className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Lead time min (days)
            <input
              name="leadMinDays"
              inputMode="numeric"
              defaultValue={product?.leadMinDays == null ? "" : String(product.leadMinDays)}
              placeholder="e.g. 14"
              className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            />
          </label>
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Lead time max (days)
            <input
              name="leadMaxDays"
              inputMode="numeric"
              defaultValue={product?.leadMaxDays == null ? "" : String(product.leadMaxDays)}
              placeholder="e.g. 21"
              className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
            />
          </label>
          <label className="flex items-center gap-3 text-sm font-medium text-artisan-sienna lg:col-span-2">
            <input name="allowCustomNote" type="checkbox" defaultChecked={product?.allowCustomNote ?? false} />
            Let buyers add a custom request note on made-to-order items
          </label>
        </div>
      </section>

      <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
        <h3 className="text-2xl font-semibold text-artisan-sienna">Images</h3>
        <p className="mt-1 text-sm text-muted-foreground">Upload and crop new product photos, or paste existing hosted URLs below.</p>
        <div className="mt-5 grid gap-4">
          <ProductImagePicker />
          <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
            Existing image URLs
            <textarea
              name="imageUrls"
              defaultValue={product?.images.join("\n") ?? ""}
              className="min-h-28 rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
              placeholder="One hosted image URL per line"
            />
          </label>
        </div>
      </section>

      <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
        <h3 className="text-2xl font-semibold text-artisan-sienna">Variants and options</h3>
        <p className="mt-1 text-sm text-muted-foreground">
          Offer this product in combinations like size and colour, with a price, stock level and photos per combination.
        </p>
        <div className="mt-5">
          <VariantOptionsEditor
            initialOptionGroups={product?.optionGroups ?? []}
            initialVariants={product?.variants ?? []}
          />
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
                <input name={`shipping_price_${key}`} defaultValue={String(option?.price ?? defaultShippingPrice(key))} className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
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
