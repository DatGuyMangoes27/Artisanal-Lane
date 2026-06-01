import Link from "next/link";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel, VendorSetupRequired } from "@/components/vendor/vendor-shell";
import { getVendorShop, listVendorShopPosts, requireVendorSession } from "@/lib/marketplace/vendor-data";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

export default async function VendorPostsPage() {
  const { user } = await requireVendorSession("/vendor/profile/posts");
  const shop = await getVendorShop(user.id);
  if (!shop) {
    return (
      <div>
        <VendorPageHeader
          eyebrow="Community"
          title="Shop posts"
          description="Create and publish updates that appear on your public artisan profile."
        />
        <VendorSetupRequired title="Create your shop before publishing posts" />
      </div>
    );
  }

  const posts = await listVendorShopPosts(shop.id);

  return (
    <div>
      <VendorPageHeader
        eyebrow="Community"
        title="Shop posts"
        description="Create and publish updates that appear on your public artisan profile."
        actions={
          <Button asChild className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
            <Link href="/vendor/profile/posts/new">New post</Link>
          </Button>
        }
      />
      <VendorPanel title="Posts">
        {posts.length === 0 ? (
          <p className="text-sm text-muted-foreground">No posts yet.</p>
        ) : null}
        <div className="grid gap-3">
          {posts.map((post) => (
            <Link key={post.id} href={`/vendor/profile/posts/${post.id}`} className="rounded-3xl border border-artisan-clay/70 p-4 text-sm transition hover:bg-artisan-bone/40">
              <div className="flex items-center justify-between gap-3">
                <p className="font-medium text-artisan-sienna line-clamp-1">{post.caption}</p>
                <span>{formatVendorStatus(post.isPublished ? "published" : "draft")}</span>
              </div>
              <p className="mt-2 text-muted-foreground">{post.mediaUrls.length} media items</p>
            </Link>
          ))}
        </div>
      </VendorPanel>
    </div>
  );
}
