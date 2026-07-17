import Link from "next/link";
import { Archive, ArchiveRestore, EyeOff, RefreshCcw, Star } from "lucide-react";

import {
  toggleProductArchived,
  toggleProductFeatured,
  toggleProductPublish,
} from "@/app/admin/actions";
import { AdminActionButtonForm } from "@/components/admin/admin-action-button-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { listProducts } from "@/lib/admin-data";

function formatCurrency(value: number) {
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
    maximumFractionDigits: 0,
  }).format(value);
}

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
  filters: { query: string; status: string; sort: string },
  page: number,
) {
  const params = new URLSearchParams();
  if (filters.query) params.set("query", filters.query);
  if (filters.status) params.set("status", filters.status);
  if (filters.sort !== "newest") params.set("sort", filters.sort);
  if (page > 1) params.set("page", String(page));

  const queryString = params.toString();
  return queryString ? `/admin/products?${queryString}` : "/admin/products";
}

export default async function AdminProductsPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const params = await searchParams;
  const query = readParam(params.query);
  const status = readParam(params.status);
  const sort = readParam(params.sort, "newest");
  const requestedPage = readPage(params.page);
  const productPage = await listProducts({
    query,
    status,
    sort,
    page: requestedPage,
  });
  const { items: products, page, pageSize, total, totalPages } = productPage;
  const firstProduct = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const lastProduct = Math.min(page * pageSize, total);
  const pageFilters = { query, status, sort };

  return (
    <>
      <AdminPageHeader
        eyebrow="Product Moderation"
        title="Catalogue Review"
        description="Unpublish or republish listings to maintain marketplace quality."
      />

      <PanelCard
        description="The current implementation focuses on publication state moderation. Category and shop context are included for quick triage."
        title="Products"
      >
        <form className="mb-6 grid gap-3 md:grid-cols-4" method="get">
          <input
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={query}
            name="query"
            placeholder="Search title, shop, category"
            type="search"
          />
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={status}
            name="status"
          >
            <option value="">All active statuses</option>
            <option value="published">Published</option>
            <option value="unpublished">Unpublished</option>
            <option value="archived">Archived</option>
          </select>
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={sort}
            name="sort"
          >
            <option value="newest">Newest first</option>
            <option value="oldest">Oldest first</option>
            <option value="price-high">Price high to low</option>
            <option value="price-low">Price low to high</option>
            <option value="stock-high">Highest stock</option>
            <option value="title">Title A-Z</option>
            <option value="featured">Featured first</option>
          </select>
          <div className="flex gap-3">
            <Button className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90" type="submit">
              Apply
            </Button>
            <Button asChild type="button" variant="outline">
              <Link href="/admin/products">Reset</Link>
            </Button>
          </div>
        </form>

        <div className="mb-4 flex flex-wrap items-center justify-between gap-3 text-sm text-muted-foreground">
          <p>
            {total === 0
              ? "No products found"
              : `Showing ${firstProduct}-${lastProduct} of ${total} products`}
          </p>
          {total > 0 ? (
            <p>
              Page {page} of {totalPages}
            </p>
          ) : null}
        </div>

        <div className="space-y-4">
          {products.length === 0 ? (
            <div className="rounded-3xl border border-dashed border-artisan-clay bg-white p-8 text-sm text-muted-foreground">
              No products match the current filters.
            </div>
          ) : null}
          {products.map((product) => (
            <div
              key={product.id}
              className="flex flex-col gap-4 rounded-3xl border border-artisan-clay bg-white p-5 xl:flex-row xl:items-center xl:justify-between"
            >
              <div className="flex flex-col gap-4 md:flex-row md:items-start">
                <div
                  aria-label={`${product.title} image`}
                  className="h-28 w-full shrink-0 rounded-2xl border border-artisan-clay bg-artisan-bone bg-cover bg-center md:w-28"
                  style={{
                    backgroundImage: product.images[0]
                      ? `url("${product.images[0]}")`
                      : undefined,
                  }}
                />

                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-xl font-semibold text-artisan-sienna">
                      {product.title}
                    </h3>
                    <StatusBadge
                      value={
                        product.archived_at
                          ? "archived"
                          : product.is_published
                            ? "published"
                            : "unpublished"
                      }
                    />
                    {product.is_featured ? <StatusBadge value="featured" /> : null}
                  </div>
                  <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-3">
                    <p>
                      <span className="font-medium text-artisan-sienna">Shop:</span>{" "}
                      {product.shop?.name ?? "Unknown shop"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Category:</span>{" "}
                      {product.category?.name ?? "Uncategorised"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Price:</span>{" "}
                      {formatCurrency(product.price)}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Stock:</span>{" "}
                      {product.stock_qty}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Created:</span>{" "}
                      {new Date(product.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex shrink-0 flex-col gap-3 sm:flex-row xl:flex-col">
                <AdminActionButtonForm
                  action={toggleProductFeatured}
                  buttonClassName={
                    product.is_featured
                      ? "w-full bg-artisan-ochre text-white hover:bg-artisan-ochre/90"
                      : "w-full bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
                  }
                  hiddenFields={[
                    { name: "productId", value: product.id },
                    { name: "nextValue", value: String(!product.is_featured) },
                  ]}
                  idleContent={
                    <>
                      <Star className="mr-2 h-4 w-4" />
                      {product.is_featured ? "Unfeature" : "Feature"}
                    </>
                  }
                  pendingLabel="Saving..."
                />

                {product.archived_at == null ? (
                  <AdminActionButtonForm
                    action={toggleProductPublish}
                    buttonClassName={
                      product.is_published
                        ? "w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                        : "w-full bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                    }
                    hiddenFields={[
                      { name: "productId", value: product.id },
                      { name: "nextValue", value: String(!product.is_published) },
                    ]}
                    idleContent={
                      product.is_published ? (
                        <>
                          <EyeOff className="mr-2 h-4 w-4" />
                          Unpublish
                        </>
                      ) : (
                        <>
                          <RefreshCcw className="mr-2 h-4 w-4" />
                          Republish
                        </>
                      )
                    }
                    pendingLabel="Saving..."
                  />
                ) : null}

                <AdminActionButtonForm
                  action={toggleProductArchived}
                  buttonClassName={
                    product.archived_at
                      ? "w-full bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                      : "w-full bg-red-800 text-white hover:bg-red-900"
                  }
                  hiddenFields={[
                    { name: "productId", value: product.id },
                    { name: "nextValue", value: String(!product.archived_at) },
                  ]}
                  idleContent={
                    product.archived_at ? (
                      <>
                        <ArchiveRestore className="mr-2 h-4 w-4" />
                        Restore
                      </>
                    ) : (
                      <>
                        <Archive className="mr-2 h-4 w-4" />
                        Archive
                      </>
                    )
                  }
                  pendingLabel="Saving..."
                />
              </div>
            </div>
          ))}
        </div>

        {total > 0 && totalPages > 1 ? (
          <nav
            aria-label="Product catalogue pagination"
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
