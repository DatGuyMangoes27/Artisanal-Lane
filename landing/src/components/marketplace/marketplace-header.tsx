import Link from "next/link";
import { Search, ShoppingBag, UserRound } from "lucide-react";

import { Button } from "@/components/ui/button";

export function MarketplaceHeader() {
  return (
    <header className="sticky top-0 z-40 border-b border-artisan-clay/70 bg-background/90 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <Link href="/shop" className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-lg bg-gradient-to-br from-artisan-terracotta to-artisan-clay font-serif text-lg font-bold text-white shadow-sm">
            A
          </span>
          <span className="font-serif text-xl font-bold text-foreground">Artisan Lane</span>
        </Link>
        <nav className="hidden items-center gap-6 text-sm font-medium text-muted-foreground md:flex">
          <Link href="/shop" className="transition hover:text-foreground">Shop</Link>
          <Link href="/shop?sort=newest" className="transition hover:text-foreground">Fresh arrivals</Link>
          <Link href="/shop#artisans" className="transition hover:text-foreground">Artisans</Link>
        </nav>
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="icon" aria-label="Search">
            <Link href="/shop#search"><Search /></Link>
          </Button>
          <Button asChild variant="ghost" size="icon" aria-label="Cart">
            <Link href="/cart"><ShoppingBag /></Link>
          </Button>
          <Button asChild variant="ghost" size="icon" aria-label="Account">
            <Link href="/account"><UserRound /></Link>
          </Button>
        </div>
      </div>
    </header>
  );
}
