import Link from "next/link";
import { ArrowRight, MessageSquare, Star, Store, Trash2 } from "lucide-react";

import { deleteShop, toggleShopSpotlight, toggleShopStatus } from "@/app/admin/actions";
import { AdminActionButtonForm } from "@/components/admin/admin-action-button-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { listShops } from "@/lib/admin-data";

function readParam(
  value: string | string[] | undefined,
  fallback = "",
) {
  return typeof value === "string" ? value : fallback;
}

function readPage(value: string | string[] | undefined) {
  const page = Number(readParam(value, "1"));
  return Number.isInteger(page) && page > 0 ? page : 1;
}

function buildPageHref(
  filters: {
    query: string;
    status: string;
    availability: string;
    sort: string;
  },
  page: number,
) {
  const params = new URLSearchParams();
  if (filters.query) params.set("query", filters.query);
  if (filters.status) params.set("status", filters.status);
  if (filters.availability) params.set("availability", filters.availability);
  if (filters.sort !== "newest") params.set("sort", filters.sort);
  if (page > 1) params.set("page", String(page));

  const queryString = params.toString();
  return queryString ? `/admin/shops?${queryString}` : "/admin/shops";
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
  const requestedPage = readPage(params.page);
  const shopPage = await listShops({
    query,
    status,
    availability,
    sort,
    page: requestedPage,
    pageSize: 20,
  });
  const { items: shops, page, pageSize, total, totalPages } = shopPage;
  const firstShop = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const lastShop = Math.min(page * pageSize, total);
  const pageFilters = { query, status, availability, sort };

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

        <div className="mb-4 flex flex-wrap items-center justify-between gap-3 text-sm text-muted-foreground">
          <p>
            {total === 0
              ? "No shops found"
              : `Showing ${firstShop}-${lastShop} of ${total} shops`}
          </p>
          {total > 0 ? (
            <p>
              Page {page} of {totalPages}
            </p>
          ) : null}
        </div>

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
                    {shop.is_spotlight ? <StatusBadge value="spotlight" /> : null}
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
                    {shop.spotlighted_at ? (
                      <p>
                        <span className="font-medium text-artisan-sienna">
                          Spotlighted:
                        </span>{" "}
                        {new Date(shop.spotlighted_at).toLocaleDateString()}
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

                <Button
                  asChild
                  className="w-full bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                >
                  <Link href={`/admin/shops/${shop.id}/messages`}>
                    <MessageSquare className="h-4 w-4" />
                    Message store
                  </Link>
                </Button>

                <AdminActionButtonForm
                  action={toggleShopSpotlight}
                  buttonClassName={
                    shop.is_spotlight
                      ? "w-full bg-artisan-ochre text-white hover:bg-artisan-ochre/90"
                      : "w-full bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
                  }
                  hiddenFields={[
                    { name: "shopId", value: shop.id },
                    { name: "nextValue", value: String(!shop.is_spotlight) },
                  ]}
                  idleContent={
                    <>
                      <Star className="h-4 w-4" />
                      {shop.is_spotlight ? "Remove spotlight" : "Spotlight artist"}
                    </>
                  }
                  pendingLabel="Saving..."
                />

                <AdminActionButtonForm
                  action={toggleShopStatus}
                  buttonClassName={
                    shop.is_active
                      ? "w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                      : "w-full bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                  }
                  hiddenFields={[
                    { name: "shopId", value: shop.id },
                    { name: "nextValue", value: String(!shop.is_active) },
                  ]}
                  idleContent={shop.is_active ? "Suspend shop" : "Restore shop"}
                  pendingLabel="Saving..."
                />
                <AdminActionButtonForm
                  action={deleteShop}
                  buttonClassName="w-full bg-red-700 text-white hover:bg-red-800"
                  confirmMessage="Delete this shop and all linked storefront content? Existing order history will be preserved, but products, posts, reviews, chats, and notes tied to the shop will be removed."
                  hiddenFields={[{ name: "shopId", value: shop.id }]}
                  idleContent={
                    <>
                      <Trash2 className="h-4 w-4" />
                      Delete shop
                    </>
                  }
                  pendingLabel="Deleting..."
                />
              </div>
            </div>
          ))}
        </div>

        {total > 0 && totalPages > 1 ? (
          <nav
            aria-label="Store directory pagination"
            className="mt-6 flex flex-wrap items-center justify-between gap-3 border-t border-artisan-clay pt-5"
          >
            {page > 1 ? (
              <Button asChild variant="outline">
                <Link href={buildPageHref(pageFilters, page - 1)}>Previous</Link>
              </Button>
            ) : (
              <Button disabled variant="outline">
                Previous
              </Button>
            )}

            <span className="text-sm text-muted-foreground">
              Page {page} of {totalPages}
            </span>

            {page < totalPages ? (
              <Button asChild variant="outline">
                <Link href={buildPageHref(pageFilters, page + 1)}>Next</Link>
              </Button>
            ) : (
              <Button disabled variant="outline">
                Next
              </Button>
            )}
          </nav>
        ) : null}
      </PanelCard>
    </>
  );
}
