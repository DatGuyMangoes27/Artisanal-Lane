import type { Metadata } from "next";

import { ForgotPasswordForm } from "@/components/marketplace/forgot-password-form";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export const metadata: Metadata = {
  title: "Forgot password | Artisan Lane",
};

export default function ForgotPasswordPage() {
  return (
    <>
      <MarketplaceHeader />
      <main className="relative flex min-h-[calc(100vh-4rem)] items-center justify-center overflow-hidden bg-[radial-gradient(circle_at_top,#f7e4cc_0%,#fdf5ec_45%,#fffaf5_100%)] px-4 py-12">
        <div className="pattern-bg absolute inset-0 opacity-20" />
        <div className="relative z-10 w-full max-w-md">
          <div className="mb-8 text-center">
            <p className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">
              Artisan Lane
            </p>
            <h1 className="mt-3 font-serif text-5xl font-semibold text-artisan-sienna">
              Account recovery
            </h1>
            <p className="mt-3 text-sm text-muted-foreground">
              We will help you get securely back into your account.
            </p>
          </div>
          <ForgotPasswordForm />
        </div>
      </main>
    </>
  );
}
