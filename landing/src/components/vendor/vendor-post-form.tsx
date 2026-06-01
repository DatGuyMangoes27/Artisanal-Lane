import { Button } from "@/components/ui/button";
import type { VendorShopPost } from "@/lib/marketplace/vendor-data";

export function VendorPostForm({
  action,
  post,
  submitLabel,
}: {
  action: (formData: FormData) => void | Promise<void>;
  post?: VendorShopPost | null;
  submitLabel: string;
}) {
  return (
    <form action={action} className="grid gap-6 rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
      {post ? <input type="hidden" name="postId" value={post.id} /> : null}
      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Caption
        <textarea name="caption" required defaultValue={post?.caption ?? ""} className="min-h-40 rounded-2xl border border-artisan-clay px-4 py-3 text-sm text-foreground" />
      </label>
      <label className="grid gap-2 text-sm font-medium text-artisan-sienna">
        Media URLs
        <textarea name="mediaUrls" defaultValue={post?.mediaUrls.join("\n") ?? ""} placeholder="One hosted media URL per line" className="min-h-28 rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
      </label>
      <input name="mediaFiles" type="file" accept="image/*,video/*" multiple className="text-sm" />
      <label className="flex items-center gap-3 text-sm font-medium text-artisan-sienna">
        <input name="isPublished" type="checkbox" defaultChecked={post?.isPublished ?? true} />
        Publish on public shop profile
      </label>
      <Button className="w-fit rounded-full bg-artisan-terracotta px-8 hover:bg-artisan-terracotta/90">
        {submitLabel}
      </Button>
    </form>
  );
}
