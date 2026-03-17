"use client";

import { useActionState, useEffect, useRef } from "react";

import { createShopNote } from "@/app/admin/actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { initialAdminActionState } from "@/lib/admin-action-state";

export function ShopNoteForm({ shopId }: { shopId: string }) {
  const [state, formAction, pending] = useActionState(
    createShopNote,
    initialAdminActionState,
  );
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (state.status === "success") {
      formRef.current?.reset();
    }
  }, [state.status]);

  return (
    <form action={formAction} className="space-y-3" ref={formRef}>
      <input name="shopId" type="hidden" value={shopId} />
      <textarea
        className="min-h-28 w-full rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-artisan-sienna outline-none transition focus:border-artisan-terracotta"
        name="note"
        placeholder="Leave an internal note for the admin team..."
      />
      <div className="flex flex-wrap items-center gap-3">
        <Button
          className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
          disabled={pending}
          type="submit"
        >
          {pending ? "Saving..." : "Save note"}
        </Button>
        <AdminActionFeedback state={state} />
      </div>
    </form>
  );
}
