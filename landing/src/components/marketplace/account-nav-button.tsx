"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { UserRound } from "lucide-react";

import { Button } from "@/components/ui/button";
import { getAccountHomeHref } from "@/lib/marketplace/account-routing";
import { createClient } from "@/lib/supabase/browser";

export function AccountNavButton() {
  const [href, setHref] = useState("/login?redirect=%2Faccount");

  useEffect(() => {
    let active = true;
    const supabase = createClient();

    async function loadAccountHref() {
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (!active || !user) {
        return;
      }

      const { data: profile } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .maybeSingle();

      if (active) {
        setHref(getAccountHomeHref((profile as { role?: string | null } | null)?.role ?? "buyer"));
      }
    }

    void loadAccountHref();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      void loadAccountHref();
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  return (
    <Button asChild variant="ghost" size="icon" aria-label="Account">
      <Link href={href}>
        <UserRound />
      </Link>
    </Button>
  );
}
