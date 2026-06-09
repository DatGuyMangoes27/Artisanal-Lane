"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/browser";

export function AuthCtaButtons({ variant = "bar" }: { variant?: "bar" | "pill" }) {
  const [loggedIn, setLoggedIn] = useState<boolean | null>(null);

  useEffect(() => {
    let active = true;
    const supabase = createClient();

    async function loadUser() {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (active) {
        setLoggedIn(Boolean(user));
      }
    }

    void loadUser();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      void loadUser();
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  // Hide the CTAs once we know a user is signed in; the account icon covers them.
  if (loggedIn === true) {
    return null;
  }

  if (variant === "pill") {
    return (
      <>
        <Link
          href="/login?intent=buyer"
          className="whitespace-nowrap rounded-full border border-artisan-clay bg-card px-4 py-2 text-sm font-semibold text-foreground shadow-sm transition hover:border-artisan-terracotta hover:text-artisan-terracotta"
        >
          Sign up
        </Link>
        <Link
          href="/login?intent=vendor"
          className="whitespace-nowrap rounded-full bg-artisan-terracotta px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-artisan-terracotta-dark"
        >
          Apply
        </Link>
      </>
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
