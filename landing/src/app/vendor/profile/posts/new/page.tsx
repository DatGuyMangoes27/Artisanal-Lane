import { VendorPostForm } from "@/components/vendor/vendor-post-form";
import { VendorPageHeader, VendorSubscribeToPost } from "@/components/vendor/vendor-shell";
import { createVendorPost } from "@/app/vendor/actions";
import { getVendorSubscription, requireVendorShop } from "@/lib/marketplace/vendor-data";
import { isVendorSubscriptionActive } from "@/lib/marketplace/vendor-utils";

export default async function NewVendorPostPage() {
  const { user } = await requireVendorShop("/vendor/profile/posts/new");
  const canPublish = isVendorSubscriptionActive(await getVendorSubscription(user.id));

  return (
    <div>
      <VendorPageHeader
        eyebrow="Community"
        title="New shop post"
        description="Publish a public update for your followers and shop visitors."
      />
      {canPublish ? null : <VendorSubscribeToPost />}
      <VendorPostForm action={createVendorPost} submitLabel="Create post" />
    </div>
  );
}
