"use client";
import { useActionState } from "react";
import { saveEmailUpdates } from "@/app/account/email-updates/actions";

export function EmailUpdatesForm({ enabled }: { enabled: boolean }) {
  const [state, action, pending] = useActionState(saveEmailUpdates, { message: "" });
  return <form action={action} className="mt-8 space-y-6">
    <label className="flex items-start gap-3 leading-6"><input type="checkbox" name="enabled" defaultChecked={enabled} className="mt-1 size-5 accent-[#7A0000]" /><span>Yes, email me Artisan Lane news, new arrivals and special offers. This is optional, and I can unsubscribe here at any time.</span></label>
    <p className="text-sm text-muted-foreground">This does not change essential order or account messages.</p>
    <button disabled={pending} className="rounded-full bg-primary px-6 py-3 font-semibold text-primary-foreground disabled:opacity-50">{pending ? "Saving…" : "Save preference"}</button>
    <p role="status" className="text-sm">{state.message}</p>
  </form>;
}
