import Link from "next/link";
import { ArrowRight, Store } from "lucide-react";

import { toggleShopStatus } from "@/app/admin/actions";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { listShops } from "@/lib/admin-data";

function readParam(
  value: string | string[] | undefined,
  fallback = "",
) {
  return typeof value === "string" ? value : fallback;
}

export default async function AdminShopsPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const params = await searchParams;
  const query = readParam(params.query);
  const status = readParam(params.status);
  const availability = readParam(params.availability);
  const sort = readParam(params.sort, "newest");
  const shops = await listShops({ query, status, availability, sort });

  return (
    <>
      <AdminPageHeader
        eyebrow="Shop Moderation"
        title="Stores"
        description="Review store status, jump into their catalogue and posts, and suspend sellers when needed."
      />

      <PanelCard
        title="Store Directory"
        description="Each row includes seller context, product volume, post volume, and current storefront availability."
      >
        <form className="mb-6 grid gap-3 md:grid-cols-5" method="get">
          <input
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={query}
            name="query"
            placeholder="Search shop, vendor, location"
            type="search"
          />
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={status}
            name="status"
          >
            <option value="">All statuses</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
          </select>
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={availability}
            name="availability"
          >
            <option value="">All availability</option>
            <option value="online">Online</option>
            <option value="offline">Offline</option>
          </select>
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={sort}
            name="sort"
          >
            <option value="newest">Newest first</option>
            <option value="oldest">Oldest first</option>
            <option value="name">Name A-Z</option>
            <option value="products-high">Most products</option>
            <option value="posts-high">Most posts</option>
          </select>
          <div className="flex gap-3">
            <Button className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90" type="submit">
              Apply
            </Button>
            <Button asChild type="button" variant="outline">
              <Link href="/admin/shops">Reset</Link>
            </Button>
          </div>
        </form>

        <div className="space-y-4">
          {shops.length === 0 ? (
            <div className="rounded-3xl border border-dashed border-artisan-clay bg-white p-8 text-sm text-muted-foreground">
              No shops match the current filters.
            </div>
          ) : null}
          {shops.map((shop) => (
            <div
              key={shop.id}
              className="flex flex-col gap-4 rounded-3xl border border-artisan-clay bg-white p-5 xl:flex-row xl:items-center xl:justify-between"
            >
              <div className="flex flex-col gap-4 md:flex-row md:items-start">
                <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-artisan-clay bg-artisan-bone">
                  {shop.logo_url ? (
                    <div
                      aria-label={`${shop.name} logo`}
                      className="h-full w-full bg-cover bg-center"
                      style={{ backgroundImage: `url("${shop.logo_url}")` }}
                    />
                  ) : (
                    <Store className="h-6 w-6 text-artisan-sienna" />
                  )}
                </div>

                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-xl font-semibold text-artisan-sienna">
                      {shop.name}
                    </h3>
                    <StatusBadge value={shop.is_active ? "active" : "suspended"} />
                    {shop.is_offline ? <StatusBadge value="offline" /> : null}
                  </div>

                  <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-2 xl:grid-cols-4">
                    <p>
                      <span className="font-medium text-artisan-sienna">Vendor:</span>{" "}
                      {shop.vendor?.display_name ?? shop.vendor?.email ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Location:</span>{" "}
                      {shop.location ?? "Not provided"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Products:</span>{" "}
                      {shop.productCount}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Posts:</span>{" "}
                      {shop.publishedPostCount}/{shop.totalPostCount} published
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Created:</span>{" "}
                      {shop.created_at
                        ? new Date(shop.created_at).toLocaleDateString()
                        : "Unknown"}
                    </p>
                    {shop.back_to_work_date ? (
                      <p>
                        <span className="font-medium text-artisan-sienna">
                          Back to work:
                        </span>{" "}
                        {new Date(shop.back_to_work_date).toLocaleDateString()}
                      </p>
                    ) : null}
                  </div>
                </div>
              </div>

              <div className="flex shrink-0 flex-col gap-3 sm:flex-row xl:flex-col">
                <Button asChild className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90">
                  <Link href={`/admin/shops/${shop.id}`}>
                    View store
                    <ArrowRight className="h-4 w-4" />
                  </Link>
                </Button>

                <form action={toggleShopStatus}>
                  <input name="shopId" type="hidden" value={shop.id} />
                  <input
                    name="nextValue"
                    type="hidden"
                    value={String(!shop.is_active)}
                  />
                  <Button
                    className={
                      shop.is_active
                        ? "w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                        : "w-full bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                    }
                    type="submit"
                  >
                    {shop.is_active ? "Suspend shop" : "Restore shop"}
                  </Button>
                </form>
              </div>
            </div>
          ))}
        </div>
      </PanelCard>
    </>
  );
}
