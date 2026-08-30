import Link from "next/link";
import Image from "next/image";
import { Heart, Search } from "lucide-react";

import { AuthCtaButtons } from "@/components/marketplace/auth-cta-buttons";
import { CartNavButton } from "@/components/marketplace/cart-nav-button";
import { FloatingCartNotice } from "@/components/marketplace/floating-cart-notice";
import { TutorialsNavLink } from "@/components/marketplace/learn-nav-link";
import { MobileNavMenu } from "@/components/marketplace/mobile-nav-menu";
import { Button } from "@/components/ui/button";

type MarketplaceHeaderProps = {
  activeItem?: "home" | "shop" | "artisans" | "tutorials" | "about";
};

function navLinkClass(isActive = false) {
  return isActive
    ? "font-semibold text-[#8F120D]"
    : "text-[#60483B] transition hover:text-[#8F120D]";
}

export function MarketplaceHeader({ activeItem }: MarketplaceHeaderProps) {
  return (
    <>
      <header className="sticky top-0 z-40 border-b border-[#E7D4C2] bg-[#FFF9F2]/96 backdrop-blur-xl">
        <div className="mx-auto flex h-[72px] max-w-[1500px] items-center gap-5 px-4 sm:px-7 lg:h-[76px]">
          <Link href="/" className="flex shrink-0 items-center gap-3.5" aria-label="Artisan Lane home">
            <Image src="/logo.png" alt="Artisan Lane Logo" width={44} height={44} className="rounded-full shadow-sm ring-1 ring-artisan-clay" />
            <span className="hidden sm:block">
              <span className="block font-serif text-[1.35rem] font-bold leading-none tracking-[-0.03em] text-[#351711]">Artisan Lane</span>
            </span>
          </Link>

          <nav className="mx-auto hidden items-center gap-8 text-sm md:flex">
            <Link href="/" className={navLinkClass(activeItem === "home")}>Home</Link>
            <Link href="/shop" className={navLinkClass(activeItem === "shop")}>Shop</Link>
            <Link href="/artisans" className={navLinkClass(activeItem === "artisans")}>Browse artisans</Link>
            <Link href="/about" className={navLinkClass(activeItem === "about")}>Our story</Link>
            <TutorialsNavLink active={activeItem === "tutorials"} />
          </nav>

          <div className="ml-auto flex shrink-0 items-center gap-1 md:ml-0">
            <Button asChild variant="ghost" size="icon" aria-label="Search">
              <Link href="/shop#search"><Search /></Link>
            </Button>
            <Button asChild variant="ghost" size="icon" aria-label="Favourites" className="hidden sm:inline-flex">
              <Link href="/account/favourites"><Heart /></Link>
            </Button>
            <CartNavButton />
            <div className="ml-2 hidden items-center gap-2 lg:flex"><AuthCtaButtons /></div>
            <MobileNavMenu activeItem={activeItem} />
          </div>
        </div>
      </header>
      <FloatingCartNotice />
    </>
  );
}
