"use client";

import { useEffect } from "react";

import { AUTH_HASH_STORAGE_KEY, parseAuthHash } from "@/lib/auth/auth-hash";

/**
 * Finishes email links whose session arrived in the URL fragment. The fragment
 * is moved to sessionStorage and stripped from the address by an inline head
 * script before analytics load, so tokens never reach third parties.
 */
export function AuthHashHandler() {
  useEffect(() => {
    let stored: string | null = null;
    try {
      stored = sessionStorage.getItem(AUTH_HASH_STORAGE_KEY);
      sessionStorage.removeItem(AUTH_HASH_STORAGE_KEY);
    } catch {
      return;
    }
    if (!stored) return;

    const result = parseAuthHash(stored);
    if (!result) return;
    if (result.kind === "error") {
      if (result.type === "recovery" || stored.includes("otp_expired")) {
        window.location.replace("/reset-password?status=invalid-link");
      }
      return;
    }

    void fetch("/auth/recovery/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        type: result.type,
      }),
    })
      .then((response) => response.json().catch(() => null))
      .then((data: { ok?: boolean; recovery?: boolean } | null) => {
        if (data?.recovery) {
          window.location.replace("/reset-password");
        } else if (result.type === "recovery") {
          window.location.replace("/reset-password?status=invalid-link");
        } else if (data?.ok) {
          window.location.reload();
        }
      });
  }, []);

  return null;
}
