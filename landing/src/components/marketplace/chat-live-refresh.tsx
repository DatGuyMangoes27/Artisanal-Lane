"use client";

import { useEffect, useRef, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/browser";

/** Realtime is the fast path; polling also works when replication is unavailable. */
export function ChatLiveRefresh() {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const pendingRef = useRef(false);
  useEffect(() => { pendingRef.current = pending; }, [pending]);
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const refresh = () => {
      if (document.visibilityState !== "visible" || pendingRef.current) return;
      startTransition(() => router.refresh());
    };
    const queueRefresh = () => {
      if (timer) return;
      timer = setTimeout(() => { timer = undefined; refresh(); }, 200);
    };
    const supabase = createClient();
    const channel = supabase.channel(`chat-page-${crypto.randomUUID()}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "chat_messages" }, queueRefresh)
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "chat_threads" }, queueRefresh)
      .subscribe();
    const poll = setInterval(refresh, 5000);
    document.addEventListener("visibilitychange", refresh);
    window.addEventListener("online", refresh);
    return () => {
      clearInterval(poll);
      if (timer) clearTimeout(timer);
      document.removeEventListener("visibilitychange", refresh);
      window.removeEventListener("online", refresh);
      void supabase.removeChannel(channel);
    };
  }, [router]);
  return null;
}
