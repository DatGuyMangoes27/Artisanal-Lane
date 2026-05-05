"use client";

import { useActionState, useEffect, useRef } from "react";
import { Megaphone, SendHorizonal } from "lucide-react";

import { sendAdminBroadcastMessage } from "@/app/admin/actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { initialAdminActionState } from "@/lib/admin-action-state";

export function AdminBroadcastMessageForm({
  storeCount,
}: {
  storeCount: number;
}) {
  const [state, formAction, pending] = useActionState(
    sendAdminBroadcastMessage,
    initialAdminActionState,
  );
  const formRef = useRef<HTMLFormElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (state.status === "success") {
      formRef.current?.reset();
      textareaRef.current?.focus();
    }
  }, [state.status, state.savedAt]);

  return (
    <form
      action={formAction}
      className="space-y-4 rounded-3xl border border-artisan-clay bg-white p-5"
      ref={formRef}
    >
      <div className="flex items-start gap-3">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-artisan-bone text-artisan-terracotta">
          <Megaphone className="h-5 w-5" />
        </div>
        <div className="space-y-1">
          <p className="text-base font-semibold text-artisan-sienna">
            Message all active stores
          </p>
          <p className="text-sm text-muted-foreground">
            This sends the same message into each active store&apos;s existing
            admin support thread. Right now it will reach {storeCount} stores.
          </p>
        </div>
      </div>

      <textarea
        className="min-h-28 w-full resize-y rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-artisan-sienna outline-none transition focus:border-artisan-terracotta"
        name="body"
        placeholder="Write an update for every active store..."
        ref={textareaRef}
      />

      <div className="flex flex-wrap items-center justify-between gap-3">
        <AdminActionFeedback state={state} />
        <Button
          className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
          disabled={pending || storeCount === 0}
          type="submit"
        >
          <SendHorizonal className="h-4 w-4" />
          {pending ? "Sending..." : "Send to all stores"}
        </Button>
      </div>
    </form>
  );
}
