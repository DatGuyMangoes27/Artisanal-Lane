"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export function VendorSubscriptionReturnStatus({ active }: { active: boolean }) {
  const router = useRouter();

  useEffect(() => {
    if (active) return;

    const interval = window.setInterval(() => router.refresh(), 2_000);
    const timeout = window.setTimeout(() => window.clearInterval(interval), 30_000);

    return () => {
      window.clearInterval(interval);
      window.clearTimeout(timeout);
    };
  }, [active, router]);

  if (active) {
    return (
      <p className="rounded-2xl bg-emerald-50 p-4 font-medium text-emerald-800">
        Your subscription is active and your shop tools are unlocked.
      </p>
    );
  }

  return (
    <p className="rounded-2xl bg-artisan-bone/70 p-4 text-artisan-sienna">
      PayFast is confirming your subscription. This page will update automatically;
      it can take up to a minute.
    </p>
  );
}
