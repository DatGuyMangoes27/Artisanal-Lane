import { Suspense } from "react";

import { AdminLoginForm } from "@/components/admin/admin-login-form";

export default function AdminLoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[radial-gradient(circle_at_top,#f7e4cc_0%,#fdf5ec_45%,#fffaf5_100%)] px-4 py-12">
      <div className="absolute inset-0 pattern-bg opacity-20" />
      <div className="relative z-10 w-full max-w-md">
        <div className="mb-8 text-center">
          <p className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">
            Artisan Lane
          </p>
          <h1 className="mt-3 text-5xl font-semibold text-artisan-sienna">
            Admin Panel
          </h1>
          <p className="mt-3 text-sm text-muted-foreground">
            Protected access for vendor approvals, moderation, disputes, and
            marketplace operations.
          </p>
        </div>
        <Suspense fallback={null}>
          <AdminLoginForm />
        </Suspense>
      </div>
    </main>
  );
}
