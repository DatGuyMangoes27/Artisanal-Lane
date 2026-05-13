import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";

export default function PaymentSuccessPage() {
  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          Payment started
        </p>
        <h1 className="mt-4 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
          Thanks, your order is being processed.
        </h1>
        <p className="mt-4 leading-7 text-muted-foreground">
          TradeSafe will confirm the payment with Artisan Lane. You can continue browsing while the
          order updates.
        </p>
        <Button asChild size="lg" className="mt-8 rounded-full">
          <Link href="/shop">Back to shop</Link>
        </Button>
      </main>
    </div>
  );
}
