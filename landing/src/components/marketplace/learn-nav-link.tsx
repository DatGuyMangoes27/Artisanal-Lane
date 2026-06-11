"use client";

import Link from "next/link";

import { useIsArtisan } from "@/components/marketplace/use-is-artisan";

/**
 * The Learn hub is artisan-only, so this desktop nav link only renders for
 * approved vendors and admins.
 */
export function LearnNavLink({ active = false }: { active?: boolean }) {
  const isArtisan = useIsArtisan();

  if (!isArtisan) {
    return null;
  }

  return (
    <Link
      href="/learn"
      className={
        active
          ? "font-semibold text-artisan-terracotta transition hover:text-artisan-terracotta-dark"
          : "transition hover:text-foreground"
      }
    >
      Learn
    </Link>
  );
}
