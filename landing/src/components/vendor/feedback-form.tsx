"use client";

import { createContext, useContext, useRef, useState, useTransition, type ReactNode, type FormEvent } from "react";
import { useFormStatus } from "react-dom";
import { Button } from "@/components/ui/button";

const SavingContext = createContext(false);
export function PendingSubmit({ children, className }: { children: ReactNode; className?: string }) {
  const status = useFormStatus();
  const saving = useContext(SavingContext);
  const pending = saving || status.pending;
  return <Button type="submit" className={className} disabled={pending} aria-busy={pending}>{pending ? "Saving…" : children}</Button>;
}

// Keep entered values on failure and stop repeated submissions. Redirects remain
// owned by Next's server-action dispatcher, rather than being swallowed as errors.
export function FeedbackForm({ action, children, className }: {
  action: (data: FormData) => void | Promise<void>; children: ReactNode; className?: string;
}) {
  const [pending, startTransition] = useTransition();
  const busy = useRef(false);
  const [message, setMessage] = useState("");
  const [failed, setFailed] = useState(false);
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy.current) return;
    const data = new FormData(event.currentTarget);
    busy.current = true;
    setMessage("");
    setFailed(false);
    startTransition(async () => {
      try {
        await action(data);
        setMessage("Saved successfully.");
      } catch (error) {
        if (error && typeof error === "object" && "digest" in error &&
            String(error.digest).startsWith("NEXT_REDIRECT")) throw error;
        setFailed(true);
        setMessage("We couldn’t save your changes. Check your connection and the form details, then try again. Your entries are still here.");
      } finally { busy.current = false; }
    });
  }
  return <SavingContext.Provider value={pending}><form onSubmit={submit} className={className} aria-busy={pending}>
    <fieldset disabled={pending} className="contents">{children}</fieldset>
    {pending ? <p role="status" className="text-sm font-semibold">Saving your changes… Please wait.</p> : null}
    {message ? <p role={failed ? "alert" : "status"} className={failed ? "rounded-xl bg-red-50 p-4 text-red-800" : "rounded-xl bg-green-50 p-4 text-green-800"}>{message}</p> : null}
  </form></SavingContext.Provider>;
}
