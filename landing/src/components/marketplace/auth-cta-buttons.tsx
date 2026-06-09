"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { getAccountHomeHref } from "@/lib/marketplace/account-routing";
import { createClient } from "@/lib/supabase/browser";

type AuthState =
  | { status: "loading" }
  | { status: "guest" }
  | { status: "authed"; dashboardHref: string };

const pillBase = "whitespace-nowrap rounded-full px-4 py-2 text-sm font-semibold shadow-sm transition";

export function AuthCtaButtons({ variant = "bar" }: { variant?: "bar" | "pill" }) {
  const [state, setState] = useState<AuthState>({ status: "loading" });

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
        setState({ status: "guest" });
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
      const requestedRole = (user.user_metadata as { requested_role?: string } | null)
        ?.requested_role;
      // Approved vendors/admins go to their portal; a pending vendor (still a
      // buyer-role profile) is sent to /vendor to finish their application;
      // everyone else lands on the buyer account.
      const dashboardHref =
        role === "vendor" || role === "admin"
          ? getAccountHomeHref(role)
          : requestedRole === "vendor"
            ? "/vendor"
            : "/account";

      setState({ status: "authed", dashboardHref });
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

  if (state.status === "loading") {
    return null;
  }

  if (variant === "pill") {
    if (state.status === "authed") {
      return (
        <Link
          href={state.dashboardHref}
          className={`${pillBase} bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark`}
        >
          Dashboard
        </Link>
      );
    }

    return (
      <>
        <Link
          href="/login?intent=buyer"
          className={`${pillBase} border border-artisan-clay bg-card text-foreground hover:border-artisan-terracotta hover:text-artisan-terracotta`}
        >
          Sign up
        </Link>
        <Link
          href="/login?intent=vendor"
          className={`${pillBase} bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark`}
        >
          Apply
        </Link>
      </>
    );
  }

  if (state.status === "authed") {
    return (
      <Button
        asChild
        size="sm"
        className="rounded-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
      >
        <Link href={state.dashboardHref}>Dashboard</Link>
      </Button>
    );
  }

  return (
    <>
      <Button
        asChild
        size="sm"
        variant="outline"
        className="rounded-full border-artisan-clay text-foreground hover:border-artisan-terracotta hover:text-artisan-terracotta"
      >
        <Link href="/login?intent=buyer">Sign up</Link>
      </Button>
      <Button
        asChild
        size="sm"
        className="rounded-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
      >
        <Link href="/login?intent=vendor">Apply</Link>
      </Button>
    </>
  );
}
