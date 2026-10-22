import { notFound } from "next/navigation";

import { Button } from "@/components/ui/button";
import { VendorPostForm } from "@/components/vendor/vendor-post-form";
import { VendorPageHeader, VendorPanel, VendorSubscribeToPost } from "@/components/vendor/vendor-shell";
import { deleteVendorPost, updateVendorPost } from "@/app/vendor/actions";
import { getVendorShopPost, getVendorSubscription, requireVendorShop } from "@/lib/marketplace/vendor-data";
import { isVendorSubscriptionActive } from "@/lib/marketplace/vendor-utils";

export default async function EditVendorPostPage({
  params,
}: {
  params: Promise<{ postId: string }>;
}) {
  const { postId } = await params;
  const { shop, user } = await requireVendorShop(`/vendor/profile/posts/${postId}`);
  const [post, subscription] = await Promise.all([
    getVendorShopPost(shop.id, postId),
    getVendorSubscription(user.id),
  ]);

  if (!post) {
    notFound();
  }

  return (
    <div>
      <VendorPageHeader
        eyebrow="Community"
        title="Edit shop post"
        description="Control the copy, media, and public visibility of this shop update."
      />
      {isVendorSubscriptionActive(subscription) ? null : <VendorSubscribeToPost />}
      <VendorPostForm action={updateVendorPost} post={post} submitLabel="Save post" />
      <div className="mt-6">
        <VendorPanel title="Delete post">
          <form action={deleteVendorPost}>
            <input type="hidden" name="postId" value={post.id} />
            <Button type="submit" variant="destructive">Delete post</Button>
          </form>
        </VendorPanel>
      </div>
    </div>
  );
}
