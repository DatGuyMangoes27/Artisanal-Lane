import type { Metadata } from "next";
import { cookies } from "next/headers";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { ResetPasswordForm } from "@/components/marketplace/reset-password-form";
import { PASSWORD_RECOVERY_COOKIE } from "@/lib/auth/password-recovery";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Reset password | Artisan Lane",
};

export default async function ResetPasswordPage() {
  const cookieStore = await cookies();
  const hasRecoveryMarker =
    cookieStore.get(PASSWORD_RECOVERY_COOKIE)?.value === "pending";
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const canReset = Boolean(hasRecoveryMarker && user);

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
              Secure your account
            </h1>
            <p className="mt-3 text-sm text-muted-foreground">
              Create a fresh password for your Artisan Lane account.
            </p>
          </div>
          <ResetPasswordForm canReset={canReset} />
        </div>
      </main>
    </>
  );
}
