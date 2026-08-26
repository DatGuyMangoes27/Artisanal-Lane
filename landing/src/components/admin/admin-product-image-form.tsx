"use client";

import { useActionState, useEffect, useId, useState } from "react";
import { ImagePlus, X } from "lucide-react";

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
  const [open, setOpen] = useState(false);
  const titleId = useId();

  useEffect(() => {
    if (!open) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !pending) setOpen(false);
    };
    document.addEventListener("keydown", onKeyDown);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [open, pending]);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="flex w-full items-center justify-center gap-2 rounded-2xl border border-artisan-clay/80 bg-artisan-bone/45 px-4 py-2.5 text-sm font-semibold text-artisan-sienna transition hover:bg-artisan-sand/70"
      >
        <ImagePlus className="size-4" />
        Manage photos
      </button>

      {open ? (
        <div
          className="fixed inset-0 z-[70] flex items-center justify-center bg-black/65 p-3 backdrop-blur-sm sm:p-6"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget && !pending) setOpen(false);
          }}
        >
          <section
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            className="flex max-h-[min(90vh,850px)] w-full max-w-3xl min-w-0 flex-col overflow-hidden rounded-3xl border border-artisan-clay bg-[#FFF9F2] shadow-2xl"
          >
            <header className="flex shrink-0 items-start justify-between gap-4 border-b border-artisan-clay/70 px-5 py-4 sm:px-6">
              <div className="min-w-0">
                <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-artisan-terracotta">Product photos</p>
                <h2 id={titleId} className="mt-1 truncate font-serif text-2xl font-bold text-artisan-sienna">{productTitle}</h2>
              </div>
              <button
                type="button"
                onClick={() => setOpen(false)}
                disabled={pending}
                className="flex size-10 shrink-0 items-center justify-center rounded-full border border-artisan-clay bg-white text-artisan-sienna transition hover:bg-artisan-sand disabled:opacity-50"
                aria-label="Close photo manager"
              >
                <X className="size-5" />
              </button>
            </header>

            <form action={formAction} className="grid min-w-0 gap-5 overflow-y-auto p-5 sm:p-6">
              <input type="hidden" name="productId" value={productId} />
              <p className="text-sm leading-6 text-muted-foreground">
                Add, crop or remove product photos. Changes are only published after you save.
              </p>
              <ProductImagePicker existingImages={images} />
              <div className="sticky bottom-0 -mx-5 -mb-5 grid gap-3 border-t border-artisan-clay/70 bg-[#FFF9F2]/95 p-5 backdrop-blur sm:-mx-6 sm:-mb-6 sm:flex sm:justify-end sm:p-6">
                <Button type="button" variant="outline" disabled={pending} onClick={() => setOpen(false)} className="rounded-full">Cancel</Button>
                <Button type="submit" disabled={pending} className="rounded-full bg-artisan-sienna px-7 text-white hover:bg-artisan-sienna/90">
                  {pending ? "Saving photos..." : "Save photo changes"}
                </Button>
              </div>
              <AdminActionFeedback state={state} />
            </form>
          </section>
        </div>
      ) : null}
    </>
  );
}
