import Image from "next/image";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import {
  createVendorMarketEvent,
  deleteVendorMarketEvent,
  updateVendorShopSettings,
} from "@/app/vendor/actions";
import {
  getVendorShop,
  listVendorMarketEvents,
  requireVendorSession,
} from "@/lib/marketplace/vendor-data";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

const shippingMethods = [
  ["courier_guy", "Courier Guy Locker"],
  ["courier_guy_door_to_door", "Courier Guy Door to Door"],
  ["pargo", "Pargo Pickup"],
  ["market_pickup", "Market pickup"],
] as const;

export default async function VendorShopSettingsPage() {
  const session = await requireVendorSession("/vendor/profile/shop");
  const shop = session.isApprovedVendor ? await getVendorShop(session.user.id) : null;
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
            </div>
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
                      defaultChecked={option?.enabled ?? key !== "market_pickup"}
                    />
                    {label}
                  </label>
                  <label className="grid gap-2 text-sm text-muted-foreground">
                    Price
                    <input
                      className="rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-foreground"
                      name={`shipping_price_${key}`}
                      defaultValue={String(option?.price ?? 0)}
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
