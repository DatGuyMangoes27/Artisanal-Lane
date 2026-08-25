"use client";

import { useActionState } from "react";
import { ImagePlus } from "lucide-react";

import { updateAdminProductImages } from "@/app/admin/actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { ProductImagePicker } from "@/components/vendor/product-image-picker";
import { initialAdminActionState } from "@/lib/admin-action-state";

export function AdminProductImageForm({
  productId,
  productTitle,
  images,
}: {
  productId: string;
  productTitle: string;
  images: string[];
}) {
  const [state, formAction, pending] = useActionState(
    updateAdminProductImages,
    initialAdminActionState,
  );

  return (
    <details className="group rounded-2xl border border-artisan-clay/80 bg-artisan-bone/45">
      <summary className="flex cursor-pointer list-none items-center justify-center gap-2 px-4 py-2.5 text-sm font-semibold text-artisan-sienna transition hover:bg-artisan-sand/70 [&::-webkit-details-marker]:hidden">
        <ImagePlus className="size-4" />
        Manage photos
      </summary>
      <form action={formAction} className="grid gap-4 border-t border-artisan-clay/70 p-4">
        <input type="hidden" name="productId" value={productId} />
        <p className="text-xs leading-5 text-muted-foreground">
          Add or remove photos for {productTitle}. Changes are only published after you save.
        </p>
        <ProductImagePicker existingImages={images} />
        <Button
          type="submit"
          disabled={pending}
          className="w-full rounded-full bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
        >
          {pending ? "Saving photos..." : "Save photo changes"}
        </Button>
        <AdminActionFeedback state={state} />
      </form>
    </details>
  );
}
