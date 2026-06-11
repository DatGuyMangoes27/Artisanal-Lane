"use client";

import { useState } from "react";
import Link from "next/link";
import { Menu, X } from "lucide-react";

import { AuthCtaButtons } from "@/components/marketplace/auth-cta-buttons";
import { useIsArtisan } from "@/components/marketplace/use-is-artisan";
import { Button } from "@/components/ui/button";

const navItems = [
  { href: "/", label: "Home", key: "home" },
  { href: "/shop", label: "Store", key: "shop" },
  { href: "/artisans", label: "Artisans", key: "artisans" },
  // Learn is artisan-only; filtered out below for everyone else.
  { href: "/learn", label: "Learn", key: "learn" },
  { href: "/about", label: "About", key: "about" },
  { href: "/shop#search", label: "Search", key: "search" },
] as const;

export function MobileNavMenu({ activeItem }: { activeItem?: string }) {
  const [open, setOpen] = useState(false);
  const isArtisan = useIsArtisan();
  const visibleNavItems = navItems.filter((item) => item.key !== "learn" || isArtisan);

  return (
    <div className="md:hidden">
      <Button
        type="button"
        variant="ghost"
        size="icon"
        aria-label={open ? "Close menu" : "Open menu"}
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
      >
        {open ? <X /> : <Menu />}
      </Button>

      {open ? (
        <>
          <button
            type="button"
            aria-hidden
            tabIndex={-1}
            className="fixed inset-0 top-16 z-30 bg-black/20"
            onClick={() => setOpen(false)}
          />
          <div className="absolute left-0 right-0 top-full z-40 border-b border-artisan-clay/70 bg-background/95 shadow-xl backdrop-blur-xl">
            <nav
              aria-label="Mobile marketplace navigation"
              className="mx-auto flex max-w-7xl flex-col gap-1 px-4 py-3"
            >
              {visibleNavItems.map((item) => (
                <Link
                  key={item.key}
                  href={item.href}
                  onClick={() => setOpen(false)}
                  className={
                    activeItem === item.key
                      ? "rounded-xl bg-artisan-terracotta px-4 py-3 text-sm font-semibold text-white"
                      : "rounded-xl px-4 py-3 text-sm font-medium text-foreground transition hover:bg-secondary"
                  }
                >
                  {item.label}
                </Link>
              ))}
              <div
                className="mt-2 flex flex-wrap gap-2 border-t border-artisan-clay/50 pt-3"
                onClick={() => setOpen(false)}
              >
                <AuthCtaButtons variant="pill" />
              </div>
            </nav>
          </div>
        </>
      ) : null}
    </div>
  );
}
