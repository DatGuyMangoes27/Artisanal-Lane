"use client";

import Link from "next/link";

import { useIsArtisan } from "@/components/marketplace/use-is-artisan";

export function TutorialsNavLink({ active = false }: { active?: boolean }) {
  return (
    <Link
      href="/tutorials"
      className={
        active
          ? "font-semibold text-artisan-terracotta transition hover:text-artisan-terracotta-dark"
          : "transition hover:text-foreground"
      }
    >
      Tutorials
    </Link>
  );
}

export function LibraryNavLink() {
  const isArtisan = useIsArtisan();

  if (!isArtisan) {
    return null;
  }

  return (
    <Link href="/vendor/library" className="transition hover:text-foreground">
      Library
    </Link>
  );
}
