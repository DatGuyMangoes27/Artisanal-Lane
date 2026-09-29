"use client";
import { useActionState } from "react";
import Link from "next/link";
import { subscribeToUpdates, unsubscribeFromUpdates } from "@/app/stay-updated/actions";

export function PublicNewsletterForm({ token }: { token?: string }) {
  const [state, action, pending] = useActionState(token ? unsubscribeFromUpdates : subscribeToUpdates, { message: "" });
  return <form action={action} className="mt-7 space-y-5">
    {token ? <input type="hidden" name="token" value={token} /> : <>
      <label className="block text-sm font-semibold">Email address<input name="email" type="email" autoComplete="email" maxLength={254} required placeholder="you@example.com" className="mt-2 block h-12 w-full rounded-xl border border-artisan-clay bg-white px-4" /></label>
      <div hidden aria-hidden="true"><input name="website" tabIndex={-1} autoComplete="off" /></div>
      <label className="flex items-start gap-3 text-sm leading-6"><input type="checkbox" name="consent" required className="mt-1 size-5 shrink-0 accent-[#7A0000]" /><span>I agree to receive Artisan Lane news, new arrivals and special offers by email. I can unsubscribe at any time.</span></label>
    </>}
    <button disabled={pending} className="rounded-full bg-primary px-7 py-3 font-semibold text-primary-foreground disabled:opacity-50">{pending ? "Saving…" : token ? "Unsubscribe" : "Keep me updated"}</button>
    <p role="status" className="text-sm leading-6">{state.message}</p>
    {state.unsubscribeUrl ? <Link href={state.unsubscribeUrl} className="block text-sm underline">Your unsubscribe link</Link> : null}
  </form>;
}
