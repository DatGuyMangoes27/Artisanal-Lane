import { createVendorCoupon, deleteVendorCoupon, toggleVendorCoupon } from "@/app/vendor/actions";
import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel, VendorSetupRequired } from "@/components/vendor/vendor-shell";
import { formatPrice } from "@/lib/marketplace/format";
import {
  getVendorShop,
  listVendorCoupons,
  listVendorProducts,
  requireVendorSession,
} from "@/lib/marketplace/vendor-data";

function formatDate(value: string | null) {
  return value
    ? new Intl.DateTimeFormat("en-ZA", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value))
    : null;
}

export default async function VendorCouponsPage() {
  const { user } = await requireVendorSession("/vendor/coupons");
  const shop = await getVendorShop(user.id);

  if (!shop) {
    return (
      <div>
        <VendorPageHeader
          eyebrow="Promotions"
          title="Discount codes"
          description="Create shop-wide or product-specific offers for your buyers."
        />
        <VendorSetupRequired title="Create your shop before adding discount codes" />
      </div>
    );
  }

  const [coupons, products] = await Promise.all([
    listVendorCoupons(shop.id),
    listVendorProducts(shop.id),
  ]);
  const inputClass = "w-full rounded-xl border border-artisan-clay bg-white px-3 py-2 text-sm";

  return (
    <div>
      <VendorPageHeader
        eyebrow="Promotions"
        title="Discount codes"
        description="Codes are validated securely at checkout and only discount products from your shop."
      />

      <VendorPanel title="Create a discount code">
        <form action={createVendorCoupon} className="grid gap-5">
          <div className="grid gap-4 md:grid-cols-2">
            <label className="space-y-2 text-sm font-medium">
              Code
              <input name="code" required minLength={3} maxLength={32} className={`${inputClass} uppercase`} placeholder="WELCOME10" />
              <span className="block text-xs font-normal text-muted-foreground">Letters, numbers, hyphens and underscores only.</span>
            </label>
            <label className="space-y-2 text-sm font-medium">
              Internal description
              <input name="description" maxLength={160} className={inputClass} placeholder="Launch promotion" />
            </label>
            <label className="space-y-2 text-sm font-medium">
              Discount type
              <select name="discountType" className={inputClass} defaultValue="percentage">
                <option value="percentage">Percentage off</option>
                <option value="fixed">Fixed rand amount off</option>
              </select>
            </label>
            <label className="space-y-2 text-sm font-medium">
              Discount value
              <input name="discountValue" required type="number" min="0.01" step="0.01" className={inputClass} placeholder="10" />
            </label>
            <label className="space-y-2 text-sm font-medium">
              Applies to
              <select name="scope" className={inputClass} defaultValue="store">
                <option value="store">Everything in my shop</option>
                <option value="products">Selected products only</option>
              </select>
            </label>
            <label className="space-y-2 text-sm font-medium">
              Minimum product total (optional)
              <input name="minimumSubtotal" type="number" min="0" step="0.01" defaultValue="0" className={inputClass} />
            </label>
            <label className="space-y-2 text-sm font-medium">
              Starts (optional)
              <input name="startsAt" type="datetime-local" className={inputClass} />
            </label>
            <label className="space-y-2 text-sm font-medium">
              Ends (optional)
              <input name="endsAt" type="datetime-local" className={inputClass} />
            </label>
          </div>

          <fieldset className="rounded-2xl border border-artisan-clay/70 p-4">
            <legend className="px-2 text-sm font-semibold">Products for product-specific codes</legend>
            <p className="mb-3 text-xs text-muted-foreground">
              You can ignore this list for a whole-shop code. For selected-product codes, choose at least one item.
            </p>
            {products.length === 0 ? (
              <p className="text-sm text-muted-foreground">Add products before creating a product-specific code.</p>
            ) : (
              <div className="grid max-h-72 gap-2 overflow-y-auto md:grid-cols-2">
                {products.map((product) => (
                  <label key={product.id} className="flex items-center gap-3 rounded-xl border border-artisan-clay/50 p-3 text-sm">
                    <input type="checkbox" name="productIds" value={product.id} />
                    <span>{product.title}</span>
                  </label>
                ))}
              </div>
            )}
          </fieldset>

          <Button type="submit" className="w-fit rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
            Create discount code
          </Button>
        </form>
      </VendorPanel>

      <VendorPanel title="Your discount codes">
        {coupons.length === 0 ? (
          <p className="rounded-2xl border border-dashed border-artisan-clay p-6 text-sm text-muted-foreground">
            You have not created any discount codes yet.
          </p>
        ) : (
          <div className="grid gap-4">
            {coupons.map((coupon) => (
              <article key={coupon.id} className="rounded-3xl border border-artisan-clay/70 p-5">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <code className="rounded-lg bg-artisan-bone px-3 py-1 text-base font-bold text-artisan-sienna">{coupon.code}</code>
                      <span className={`rounded-full px-3 py-1 text-xs font-semibold ${coupon.isActive ? "bg-green-100 text-green-800" : "bg-stone-100 text-stone-600"}`}>
                        {coupon.isActive ? "Active" : "Paused"}
                      </span>
                    </div>
                    <p className="mt-3 font-semibold text-artisan-sienna">
                      {coupon.discountType === "percentage" ? `${coupon.discountValue}% off` : `${formatPrice(coupon.discountValue)} off`}
                      {coupon.scope === "store" ? " the whole shop" : ` ${coupon.productIds.length} selected product${coupon.productIds.length === 1 ? "" : "s"}`}
                    </p>
                    {coupon.description ? <p className="mt-1 text-sm text-muted-foreground">{coupon.description}</p> : null}
                    <p className="mt-2 text-xs text-muted-foreground">
                      {coupon.minimumSubtotal > 0 ? `Minimum ${formatPrice(coupon.minimumSubtotal)} · ` : ""}
                      {formatDate(coupon.startsAt) ? `Starts ${formatDate(coupon.startsAt)} · ` : ""}
                      {formatDate(coupon.endsAt) ? `Ends ${formatDate(coupon.endsAt)}` : "No expiry"}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <form action={toggleVendorCoupon}>
                      <input type="hidden" name="couponId" value={coupon.id} />
                      <input type="hidden" name="isActive" value={coupon.isActive ? "false" : "true"} />
                      <Button type="submit" variant="outline" className="rounded-full">
                        {coupon.isActive ? "Pause" : "Activate"}
                      </Button>
                    </form>
                    <form action={deleteVendorCoupon}>
                      <input type="hidden" name="couponId" value={coupon.id} />
                      <Button type="submit" variant="destructive" className="rounded-full">Delete</Button>
                    </form>
                  </div>
                </div>
              </article>
            ))}
          </div>
        )}
      </VendorPanel>
    </div>
  );
}
