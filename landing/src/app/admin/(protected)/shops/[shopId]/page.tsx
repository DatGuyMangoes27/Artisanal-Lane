import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, EyeOff, MessageSquare, RefreshCcw, Star } from "lucide-react";

import {
  toggleShopSpotlight,
  toggleShopPostPublish,
  toggleShopStatus,
} from "@/app/admin/actions";
import { AdminActionButtonForm } from "@/components/admin/admin-action-button-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { ShopNoteForm } from "@/components/admin/shop-note-form";
import { Button } from "@/components/ui/button";
import { getShopDetail } from "@/lib/admin-data";

function formatCurrency(value: number) {
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
    maximumFractionDigits: 0,
  }).format(value);
}

export default async function AdminShopDetailPage({
  params,
}: {
  params: Promise<{ shopId: string }>;
}) {
  const { shopId } = await params;
  const shop = await getShopDetail(shopId);

  if (!shop) {
    notFound();
  }

  return (
    <>
      <AdminPageHeader
        eyebrow="Shop Moderation"
        title={shop.name}
        description="Inspect the storefront, moderate posts, review products, and leave internal notes for other admins."
        actions={
          <div className="flex flex-wrap gap-3">
            <Button asChild variant="outline">
              <Link href="/admin/shops">
                <ArrowLeft className="h-4 w-4" />
                Back to stores
              </Link>
            </Button>
            <Button
              asChild
              className="bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
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
                  ? "bg-artisan-ochre text-white hover:bg-artisan-ochre/90"
                  : "bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
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
                  ? "bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                  : "bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
              }
              hiddenFields={[
                { name: "shopId", value: shop.id },
                { name: "nextValue", value: String(!shop.is_active) },
              ]}
              idleContent={shop.is_active ? "Suspend shop" : "Restore shop"}
              pendingLabel="Saving..."
            />
          </div>
        }
      />

      <div className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <PanelCard
          title="Store Overview"
          description="Core storefront state, vendor ownership, and vacation-mode visibility."
        >
          <div className="space-y-4">
            <div className="flex flex-wrap items-center gap-3">
              <StatusBadge value={shop.is_active ? "active" : "suspended"} />
              {shop.is_spotlight ? <StatusBadge value="spotlight" /> : null}
              {shop.is_offline ? <StatusBadge value="offline" /> : null}
            </div>
            <div className="grid gap-3 text-sm text-muted-foreground md:grid-cols-2">
              <p>
                <span className="font-medium text-artisan-sienna">Vendor:</span>{" "}
                {shop.vendor?.display_name ?? shop.vendor?.email ?? "Unknown"}
              </p>
              <p>
                <span className="font-medium text-artisan-sienna">Email:</span>{" "}
                {shop.vendor?.email ?? "Unknown"}
              </p>
              <p>
                <span className="font-medium text-artisan-sienna">Location:</span>{" "}
                {shop.location ?? "Not provided"}
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
            {shop.bio ? (
              <p className="text-sm text-muted-foreground">
                <span className="font-medium text-artisan-sienna">Bio:</span>{" "}
                {shop.bio}
              </p>
            ) : null}
            {shop.brand_story ? (
              <p className="text-sm text-muted-foreground">
                <span className="font-medium text-artisan-sienna">
                  Brand story:
                </span>{" "}
                {shop.brand_story}
              </p>
            ) : null}
          </div>
        </PanelCard>

        <PanelCard
          title="Admin Notes"
          description="Private moderation notes for suspension context, follow-ups, and seller history."
        >
          <ShopNoteForm shopId={shop.id} />

          <div className="mt-5 space-y-3">
            {shop.notes.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                No admin notes yet.
              </p>
            ) : (
              shop.notes.map((note) => (
                <div
                  key={note.id}
                  className="rounded-2xl border border-artisan-clay bg-artisan-bone/40 p-4"
                >
                  <p className="text-sm text-artisan-sienna">{note.note}</p>
                  <p className="mt-2 text-xs text-muted-foreground">
                    {note.author?.display_name ?? note.author?.email ?? "Admin"} on{" "}
                    {new Date(note.created_at).toLocaleString()}
                  </p>
                </div>
              ))
            )}
          </div>
        </PanelCard>
      </div>

      <div className="mt-6 grid gap-6">
        <PanelCard
          title="Products"
          description="Current storefront catalogue with quick visibility into imagery, price, and publish state."
        >
          <div className="space-y-4">
            {shop.products.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                This shop has no products yet.
              </p>
            ) : (
              shop.products.map((product) => (
                <div
                  key={product.id}
                  className="flex flex-col gap-4 rounded-3xl border border-artisan-clay bg-white p-4 lg:flex-row lg:items-center lg:justify-between"
                >
                  <div className="flex flex-col gap-4 md:flex-row md:items-start">
                    <div
                      aria-label={`${product.title} image`}
                      className="h-24 w-full shrink-0 rounded-2xl border border-artisan-clay bg-artisan-bone bg-cover bg-center md:w-24"
                      style={{
                        backgroundImage: product.images[0]
                          ? `url("${product.images[0]}")`
                          : undefined,
                      }}
                    />
                    <div className="space-y-2">
                      <div className="flex flex-wrap items-center gap-3">
                        <h3 className="text-lg font-semibold text-artisan-sienna">
                          {product.title}
                        </h3>
                        <StatusBadge
                          value={product.is_published ? "published" : "unpublished"}
                        />
                      </div>
                      <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-3">
                        <p>
                          <span className="font-medium text-artisan-sienna">
                            Price:
                          </span>{" "}
                          {formatCurrency(product.price)}
                        </p>
                        <p>
                          <span className="font-medium text-artisan-sienna">
                            Stock:
                          </span>{" "}
                          {product.stock_qty}
                        </p>
                        <p>
                          <span className="font-medium text-artisan-sienna">
                            Created:
                          </span>{" "}
                          {new Date(product.created_at).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </PanelCard>

        <PanelCard
          title="Posts"
          description="Moderate maker posts without leaving the admin panel."
        >
          <div className="space-y-4">
            {shop.posts.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                This shop has not published any posts yet.
              </p>
            ) : (
              shop.posts.map((post) => (
                <div
                  key={post.id}
                  className="flex flex-col gap-4 rounded-3xl border border-artisan-clay bg-white p-4 lg:flex-row lg:items-center lg:justify-between"
                >
                  <div className="flex flex-col gap-4 md:flex-row md:items-start">
                    <div
                      aria-label="Shop post media"
                      className="h-24 w-full shrink-0 rounded-2xl border border-artisan-clay bg-artisan-bone bg-cover bg-center md:w-24"
                      style={{
                        backgroundImage: post.media_urls[0]
                          ? `url("${post.media_urls[0]}")`
                          : undefined,
                      }}
                    />
                    <div className="space-y-2">
                      <div className="flex flex-wrap items-center gap-3">
                        <StatusBadge
                          value={post.is_published ? "published" : "unpublished"}
                        />
                        <p className="text-sm text-muted-foreground">
                          {new Date(post.created_at).toLocaleString()}
                        </p>
                      </div>
                      <p className="text-sm text-artisan-sienna">
                        {post.caption || "No caption provided."}
                      </p>
                    </div>
                  </div>

                  <AdminActionButtonForm
                    action={toggleShopPostPublish}
                    buttonClassName={
                      post.is_published
                        ? "bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                        : "bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                    }
                    hiddenFields={[
                      { name: "shopId", value: shop.id },
                      { name: "postId", value: post.id },
                      { name: "nextValue", value: String(!post.is_published) },
                    ]}
                    idleContent={
                      post.is_published ? (
                        <>
                          <EyeOff className="h-4 w-4" />
                          Unpublish post
                        </>
                      ) : (
                        <>
                          <RefreshCcw className="h-4 w-4" />
                          Republish post
                        </>
                      )
                    }
                    pendingLabel="Saving..."
                  />
                </div>
              ))
            )}
          </div>
        </PanelCard>
      </div>
    </>
  );
}
