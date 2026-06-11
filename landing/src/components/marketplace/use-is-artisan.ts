"use client";

import { useEffect, useState } from "react";

import { createClient } from "@/lib/supabase/browser";

/**
 * Client-side check for whether the current user is an artisan (approved
 * vendor) or admin. Returns false while loading and for guests/buyers, so
 * artisan-only UI stays hidden until the role is confirmed.
 */
export function useIsArtisan() {
  const [isArtisan, setIsArtisan] = useState(false);

  useEffect(() => {
    let active = true;
    const supabase = createClient();

    async function load() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!active) {
        return;
      }
      if (!user) {
        setIsArtisan(false);
        return;
      }

      const { data: profile } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .maybeSingle();
      if (!active) {
        return;
      }

      const role = (profile as { role?: string | null } | null)?.role ?? "buyer";
      setIsArtisan(role === "vendor" || role === "admin");
    }

    void load();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      void load();
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  return isArtisan;
}
