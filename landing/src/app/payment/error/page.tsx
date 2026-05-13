import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";

export default function PaymentErrorPage() {
  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          Payment interrupted
        </p>
        <h1 className="mt-4 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
          We could not complete payment.
        </h1>
        <p className="mt-4 leading-7 text-muted-foreground">
          Your cart is still saved on this device. Review it and try TradeSafe checkout again.
        </p>
        <Button asChild size="lg" className="mt-8 rounded-full">
          <Link href="/cart">Return to cart</Link>
        </Button>
      </main>
    </div>
  );
}
