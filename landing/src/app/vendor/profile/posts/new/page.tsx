import { VendorPostForm } from "@/components/vendor/vendor-post-form";
import { VendorPageHeader } from "@/components/vendor/vendor-shell";
import { createVendorPost } from "@/app/vendor/actions";
import { requireVendorShop } from "@/lib/marketplace/vendor-data";

export default async function NewVendorPostPage() {
  await requireVendorShop("/vendor/profile/posts/new");

  return (
    <div>
      <VendorPageHeader
        eyebrow="Community"
        title="New shop post"
        description="Publish a public update for your followers and shop visitors."
      />
      <VendorPostForm action={createVendorPost} submitLabel="Create post" />
    </div>
  );
}
