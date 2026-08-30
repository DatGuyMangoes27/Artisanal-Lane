import Image from "next/image";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import {
  createVendorMarketEvent,
  deleteVendorMarketEvent,
  updateVendorShopSettings,
} from "@/app/vendor/actions";
import {
  getVendorFulfillmentProfile,
  getVendorShop,
  listVendorMarketEvents,
  requireVendorSession,
} from "@/lib/marketplace/vendor-data";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";
import {
  SHIPPING_METHOD_KEYS,
  defaultShippingPrice,
  shippingMethodName,
} from "@/lib/marketplace/shipping";

const shippingMethods = SHIPPING_METHOD_KEYS.map(
  (key) => [key, shippingMethodName(key)] as const,
);

export default async function VendorShopSettingsPage() {
  const session = await requireVendorSession("/vendor/profile/shop");
  const shop = session.isApprovedVendor ? await getVendorShop(session.user.id) : null;
  const fulfillmentProfile = shop ? await getVendorFulfillmentProfile(shop.id) : null;
  const marketEvents = shop ? await listVendorMarketEvents(shop.id) : [];
  const shopName = shop?.name ?? "";

  return (
    <div>
      <VendorPageHeader
        eyebrow="Shop Profile"
        title={shop ? "Shop settings" : "Create your shop profile"}
        description="Complete the profile buyers see: shop name, story, images, shipping defaults, market pickup, and offline mode."
      />

      <form action={updateVendorShopSettings} className="grid gap-6">
        <VendorPanel
          title="Public profile"
          description="These fields power your public artisan page and product cards."
        >
          <div className="grid gap-5 lg:grid-cols-2">
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Shop name
              <input
                required
                className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-foreground"
                name="name"
                defaultValue={shopName}
                placeholder="Your shop name"
              />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Location
              <input
                className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-foreground"
                name="location"
                defaultValue={shop?.location ?? ""}
                placeholder="City, province"
              />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
              Bio
              <textarea
                className="min-h-28 rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-foreground"
                name="bio"
                defaultValue={shop?.bio ?? ""}
                placeholder="A short introduction for your shop profile."
              />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
              Brand story
              <textarea
                className="min-h-32 rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-foreground"
                name="brandStory"
                defaultValue={shop?.brandStory ?? ""}
                placeholder="Tell buyers about your process, materials, and craft."
              />
            </label>
          </div>
        </VendorPanel>

        <VendorPanel title="Images" description="Upload replacements or paste hosted image URLs.">
          <div className="grid gap-5 lg:grid-cols-2">
            <div className="space-y-3">
              <p className="text-sm font-medium text-artisan-sienna">Logo</p>
              {shop?.logoUrl ? (
                <Image
                  alt={`${shopName} logo`}
                  src={shop.logoUrl}
                  width={96}
                  height={96}
                  className="h-24 w-24 rounded-3xl object-cover"
                />
              ) : null}
              <input type="hidden" name="logoUrl" defaultValue={shop?.logoUrl ?? ""} />
              <input name="logoFile" type="file" accept="image/*" className="text-sm" />
              {shop?.logoUrl ? (
                <label className="flex items-center gap-2 text-xs text-muted-foreground">
                  <input name="removeLogo" type="checkbox" />
                  Remove the current logo when I save
                </label>
              ) : null}
            </div>
            <div className="space-y-3">
              <p className="text-sm font-medium text-artisan-sienna">Cover image</p>
              {shop?.coverImageUrl ? (
                <Image
                  alt={`${shopName} cover`}
                  src={shop.coverImageUrl}
                  width={640}
                  height={240}
                  className="h-36 w-full rounded-3xl object-cover"
                />
              ) : null}
              <input type="hidden" name="coverImageUrl" defaultValue={shop?.coverImageUrl ?? ""} />
              <input name="coverFile" type="file" accept="image/*" className="text-sm" />
              {shop?.coverImageUrl ? (
                <label className="flex items-center gap-2 text-xs text-muted-foreground">
                  <input name="removeCover" type="checkbox" />
                  Remove the current cover image when I save
                </label>
              ) : null}
            </div>
          </div>
        </VendorPanel>

        <VendorPanel
          title="Bob Go collection address"
          description="Private courier collection details. Buyers never see this address. Bob Go is door-to-door only and remains separate from every existing delivery option."
        >
          <div className="grid gap-5 lg:grid-cols-2">
            <label className="flex items-start gap-3 rounded-2xl border border-artisan-clay/70 bg-artisan-bone/30 p-4 lg:col-span-2">
              <input
                name="bobGoEnabled"
                type="checkbox"
                defaultChecked={fulfillmentProfile?.bobGoEnabled ?? false}
                className="mt-1"
              />
              <span className="grid gap-1">
                <span className="text-sm font-semibold text-artisan-sienna">
                  Offer Bob Go door-to-door delivery
                </span>
                <span className="text-sm text-muted-foreground">
                  A live courier price will be calculated from this collection address to the buyer.
                </span>
              </span>
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Collection contact name
              <input name="collectionContactFullName" defaultValue={fulfillmentProfile?.contactFullName ?? ""} className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Company / shop name
              <input name="collectionCompany" defaultValue={fulfillmentProfile?.company ?? shopName} className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Collection email
              <input name="collectionContactEmail" type="email" defaultValue={fulfillmentProfile?.contactEmail ?? session.profile.email ?? ""} className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Collection phone
              <input name="collectionContactPhone" type="tel" defaultValue={fulfillmentProfile?.contactPhone ?? ""} placeholder="+27..." className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna lg:col-span-2">
              Street address
              <input name="collectionStreetAddress" defaultValue={fulfillmentProfile?.streetAddress ?? ""} className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Suburb / local area
              <input name="collectionLocalArea" defaultValue={fulfillmentProfile?.localArea ?? ""} className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              City
              <input name="collectionCity" defaultValue={fulfillmentProfile?.city ?? ""} className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Province
              <input name="collectionProvince" defaultValue={fulfillmentProfile?.province ?? ""} placeholder="Western Cape" className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Postal code
              <input name="collectionPostalCode" inputMode="numeric" defaultValue={fulfillmentProfile?.postalCode ?? ""} className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm" />
            </label>
          </div>
        </VendorPanel>

        <VendorPanel
          title="Availability and shipping"
          description="Defaults are copied into new products, and market pickup details show at checkout."
        >
          <div className="mb-5 grid gap-4 rounded-2xl border border-artisan-clay/70 bg-artisan-bone/30 p-4 md:grid-cols-2">
            <label className="flex items-center gap-3 text-sm font-medium text-artisan-sienna">
              <input name="isOffline" type="checkbox" defaultChecked={shop?.isOffline ?? false} />
              Offline / vacation mode
            </label>
            <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
              Back to work date
              <input
                className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm"
                name="backToWorkDate"
                type="date"
                defaultValue={shop?.backToWorkDate ?? ""}
              />
            </label>
          </div>

          <div className="grid gap-4">
            <label className="flex items-start gap-3 rounded-2xl border border-artisan-clay/70 bg-artisan-bone/30 p-4">
              <input
                name="combinedShippingEnabled"
                type="checkbox"
                defaultChecked={shop?.combinedShippingEnabled ?? true}
                className="mt-1"
              />
              <span className="grid gap-1">
                <span className="text-sm font-semibold text-artisan-sienna">
                  Combine shipping for products in the same order
                </span>
                <span className="text-sm font-normal text-muted-foreground">
                  Recommended. Buyers pay one delivery fee when ordering multiple products
                  from your shop. We use the highest applicable delivery rate. Turn this off
                  only if every item must be packed and shipped separately.
                </span>
              </span>
            </label>

            {shippingMethods.map(([key, label]) => {
              const option = shop?.shippingOptions.find((item) => item.key === key);
              return (
                <div
                  key={key}
                  className="grid gap-3 rounded-2xl border border-artisan-clay/70 p-4 md:grid-cols-[1fr_10rem_1fr]"
                >
                  <label className="flex items-center gap-3 text-sm font-medium text-artisan-sienna">
                    <input
                      name={`shipping_${key}`}
                      type="checkbox"
                      defaultChecked={option?.enabled ?? true}
                    />
                    {label}
                  </label>
                  <label className="grid gap-2 text-sm text-muted-foreground">
                    Price
                    <input
                      className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-foreground"
                      name={`shipping_price_${key}`}
                      defaultValue={String(option?.price ?? defaultShippingPrice(key))}
                    />
                  </label>
                  {key === "market_pickup" ? (
                    <div className="grid gap-2">
                      <input
                        className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm"
                        name={`shipping_market_name_${key}`}
                        placeholder="Market name"
                        defaultValue={option?.marketName ?? ""}
                      />
                      <input
                        className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm"
                        name={`shipping_market_location_${key}`}
                        placeholder="Market location"
                        defaultValue={option?.marketLocation ?? ""}
                      />
                      <input
                        className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm"
                        name={`shipping_market_province_${key}`}
                        placeholder="Province"
                        defaultValue={option?.marketProvince ?? ""}
                      />
                    </div>
                  ) : null}
                </div>
              );
            })}
          </div>
        </VendorPanel>

        <Button className="w-fit rounded-full bg-artisan-terracotta px-8 hover:bg-artisan-terracotta/90">
          {shop ? "Save shop settings" : "Create shop profile"}
        </Button>
      </form>

      <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_0.8fr]">
        <VendorPanel title="Upcoming market events">
          <div className="space-y-3">
            {!shop ? (
              <p className="text-sm text-muted-foreground">
                Save your shop profile first, then add upcoming markets.
              </p>
            ) : marketEvents.length === 0 ? (
              <p className="text-sm text-muted-foreground">No market events added yet.</p>
            ) : null}
            {marketEvents.map((event) => (
              <div
                key={event.id}
                className="flex flex-col gap-3 rounded-2xl border border-artisan-clay/70 p-4 text-sm md:flex-row md:items-center md:justify-between"
              >
                <div>
                  <p className="font-medium text-artisan-sienna">{event.marketName}</p>
                  <p className="text-muted-foreground">
                    {event.location} · {event.eventDate}
                    {event.timeLabel ? ` · ${event.timeLabel}` : ""} · {formatVendorStatus(event.isActive ? "active" : "inactive")}
                  </p>
                </div>
                <form action={deleteVendorMarketEvent}>
                  <input type="hidden" name="eventId" value={event.id} />
                  <Button type="submit" variant="outline">Delete</Button>
                </form>
              </div>
            ))}
          </div>
        </VendorPanel>

        <VendorPanel title="Add market event">
          <form action={createVendorMarketEvent} className="grid gap-3">
            <input className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" name="marketName" placeholder="Market name" required />
            <input className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" name="marketLocation" placeholder="Location" required />
            <input className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" name="eventDate" type="date" required />
            <input className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" name="timeLabel" placeholder="Time (e.g. 10:00 - 14:00)" />
            <textarea className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" name="notes" placeholder="Notes" />
            <label className="flex items-center gap-2 text-sm text-artisan-sienna">
              <input name="isActive" type="checkbox" defaultChecked />
              Show publicly
            </label>
            <Button
              className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90"
              disabled={!shop}
            >
              {shop ? "Add event" : "Save shop first"}
            </Button>
          </form>
        </VendorPanel>
      </div>
    </div>
  );
}
