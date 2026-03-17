import Link from "next/link";
import { EyeOff, RefreshCcw, Star } from "lucide-react";

import { toggleProductFeatured, toggleProductPublish } from "@/app/admin/actions";
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

export default async function AdminProductsPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const params = await searchParams;
  const query = readParam(params.query);
  const status = readParam(params.status);
  const sort = readParam(params.sort, "newest");
  const products = await listProducts({ query, status, sort });

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
            <option value="">All statuses</option>
            <option value="published">Published</option>
            <option value="unpublished">Unpublished</option>
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
                      value={product.is_published ? "published" : "unpublished"}
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
              </div>
            </div>
          ))}
        </div>
      </PanelCard>
    </>
  );
}
