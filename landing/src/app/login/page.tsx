import { Suspense } from "react";

import { BuyerLoginForm } from "@/components/marketplace/buyer-login-form";

export default function BuyerLoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[radial-gradient(circle_at_top,#f7e4cc_0%,#fdf5ec_45%,#fffaf5_100%)] px-4 py-12">
      <div className="absolute inset-0 pattern-bg opacity-20" />
      <div className="relative z-10 w-full max-w-md">
        <div className="mb-8 text-center">
          <p className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">
            Artisan Lane
          </p>
          <h1 className="mt-3 font-serif text-5xl font-semibold text-artisan-sienna">
            Buyer Account
          </h1>
          <p className="mt-3 text-sm text-muted-foreground">
            Sign in when you are ready to pay. Browsing and cart building stay open to guests.
          </p>
        </div>
        <Suspense fallback={null}>
          <BuyerLoginForm />
        </Suspense>
      </div>
    </main>
  );
}
