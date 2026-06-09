import Link from "next/link";
import Image from "next/image";
import { Heart, Search } from "lucide-react";

import { AccountNavButton } from "@/components/marketplace/account-nav-button";
import { AuthCtaButtons } from "@/components/marketplace/auth-cta-buttons";
import { CartNavButton } from "@/components/marketplace/cart-nav-button";
import { FloatingCartNotice } from "@/components/marketplace/floating-cart-notice";
import { Button } from "@/components/ui/button";

type MarketplaceHeaderProps = {
  activeItem?: "home" | "shop" | "artisans" | "learn" | "about";
};

function navLinkClass(isActive = false) {
  return isActive
    ? "font-semibold text-artisan-terracotta transition hover:text-artisan-terracotta-dark"
    : "transition hover:text-foreground";
}

function mobileNavLinkClass(isActive = false) {
  return isActive
    ? "whitespace-nowrap rounded-full bg-artisan-terracotta px-4 py-2 text-sm font-semibold text-white shadow-sm"
    : "whitespace-nowrap rounded-full border border-artisan-clay bg-card px-4 py-2 text-sm font-semibold text-foreground shadow-sm transition hover:border-artisan-terracotta hover:text-artisan-terracotta";
}

export function MarketplaceHeader({ activeItem }: MarketplaceHeaderProps) {
  return (
    <>
    <header className="sticky top-0 z-40 border-b border-artisan-clay/70 bg-background/90 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <Link href="/" className="flex items-center gap-3">
          <Image
            src="/logo.png"
            alt="Artisan Lane Logo"
            width={38}
            height={38}
            className="rounded-xl shadow-sm"
          />
          <span className="font-serif text-xl font-bold text-foreground">Artisan Lane</span>
        </Link>
        <nav className="hidden items-center gap-6 text-sm font-medium text-muted-foreground md:flex">
          <Link href="/" className={navLinkClass(activeItem === "home")}>Home</Link>
          <Link href="/shop" className={navLinkClass(activeItem === "shop")}>Store</Link>
          <Link href="/artisans" className={navLinkClass(activeItem === "artisans")}>Artisans</Link>
          <Link href="/learn" className={navLinkClass(activeItem === "learn")}>Learn</Link>
          <Link href="/about" className={navLinkClass(activeItem === "about")}>About</Link>
        </nav>
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="icon" aria-label="Search">
            <Link href="/shop#search"><Search /></Link>
          </Button>
          <CartNavButton />
          <Button asChild variant="ghost" size="icon" aria-label="Favourites">
            <Link href="/account/favourites"><Heart /></Link>
          </Button>
          <AccountNavButton />
          <div className="ml-1 hidden items-center gap-2 sm:flex">
            <AuthCtaButtons />
          </div>
        </div>
      </div>
      <nav
        aria-label="Mobile marketplace navigation"
        className="border-t border-artisan-clay/50 px-4 py-2 md:hidden"
      >
        <div className="flex gap-2 overflow-x-auto pb-1">
          <Link href="/" className={mobileNavLinkClass(activeItem === "home")}>
            Home
          </Link>
          <Link href="/shop" className={mobileNavLinkClass(activeItem === "shop")}>
            Store
          </Link>
          <Link href="/artisans" className={mobileNavLinkClass(activeItem === "artisans")}>
            Artisans
          </Link>
          <Link href="/learn" className={mobileNavLinkClass(activeItem === "learn")}>
            Learn
          </Link>
          <Link href="/about" className={mobileNavLinkClass(activeItem === "about")}>
            About
          </Link>
          <Link href="/shop#search" className={mobileNavLinkClass()}>
            Search
          </Link>
          <AuthCtaButtons variant="pill" />
        </div>
      </nav>
    </header>
    <FloatingCartNotice />
    </>
  );
}
