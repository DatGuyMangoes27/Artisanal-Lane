"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";

/**
 * Polls the current server-rendered admin page on a fixed interval so new
 * chat messages from the shop's vendor show up without a manual refresh.
 *
 * We use `router.refresh()` which re-runs the server components for the
 * current route while preserving client state (e.g. the composer text).
 * Polling pauses while the tab is hidden to avoid burning requests in the
 * background.
 */
export function AdminChatAutoRefresh({
  intervalMs = 4000,
}: {
  intervalMs?: number;
}) {
  const router = useRouter();
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    function clearTimer() {
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    }

    function startTimer() {
      clearTimer();
      timerRef.current = setInterval(() => {
        router.refresh();
      }, intervalMs);
    }

    function handleVisibilityChange() {
      if (document.visibilityState === "visible") {
        router.refresh();
        startTimer();
      } else {
        clearTimer();
      }
    }

    startTimer();
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      document.removeEventListener(
        "visibilitychange",
        handleVisibilityChange,
      );
      clearTimer();
    };
  }, [router, intervalMs]);

  return null;
}
