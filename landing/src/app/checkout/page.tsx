"use client";

import { CheckoutForm } from "@/components/marketplace/checkout-form";
import { GuestCartProvider } from "@/components/marketplace/guest-cart-provider";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export default function CheckoutPage() {
  return (
    <GuestCartProvider>
      <div className="min-h-screen bg-background">
        <MarketplaceHeader />
        <main>
          <CheckoutForm />
        </main>
      </div>
    </GuestCartProvider>
  );
}
