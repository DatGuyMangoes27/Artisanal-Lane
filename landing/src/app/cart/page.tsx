"use client";

import Link from "next/link";

import { GuestCartProvider, useGuestCart } from "@/components/marketplace/guest-cart-provider";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";

function CartStatus() {
  const { quantity } = useGuestCart();
  const itemLabel = quantity === 1 ? "item" : "items";

  return (
    <section className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
      <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
        Guest cart
      </p>
      <h1 className="mt-4 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
        Your cart foundation is ready.
      </h1>
      <div className="mt-8 rounded-[2rem] border border-artisan-clay bg-card p-8 shadow-sm">
        <p className="text-5xl font-bold text-artisan-terracotta">{quantity}</p>
        <p className="mt-2 text-lg font-semibold text-foreground">
          {itemLabel} saved on this device
        </p>
        <p className="mt-4 leading-7 text-muted-foreground">
          Full cart review, checkout, and authenticated cart sync are planned for Phase 2. For now,
          this page confirms that add-to-cart actions are stored locally for guest shoppers.
        </p>
        <Button asChild size="lg" className="mt-8 rounded-full">
          <Link href="/shop">Continue shopping</Link>
        </Button>
      </div>
    </section>
  );
}

export default function CartPage() {
  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-background">
        <MarketplaceHeader />
        <main>
          <CartStatus />
        </main>
      </div>
    </GuestCartProvider>
  );
}
