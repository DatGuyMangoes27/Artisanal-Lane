"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect } from "react";
import { Lock } from "lucide-react";

import { Button } from "@/components/ui/button";

const SUBSCRIPTION_PATH = "/vendor/profile/subscription";

/**
 * Non-dismissable modal shown to approved vendors who do not have an active
 * subscription. It blocks the portal until they subscribe, but stays hidden on
 * the subscription page itself so they can actually complete checkout.
 */
export function VendorSubscriptionGate({ active }: { active: boolean }) {
  const pathname = usePathname();
  const onSubscriptionPage = pathname?.startsWith(SUBSCRIPTION_PATH) ?? false;
  const visible = active && !onSubscriptionPage;

  // Lock background scroll while the gate is up.
  useEffect(() => {
    if (!visible) {
      return;
    }
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [visible]);

  if (!visible) {
    return null;
  }

  return (
    <div
      role="alertdialog"
      aria-modal="true"
      aria-labelledby="subscription-gate-title"
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
    >
      <div className="w-full max-w-md rounded-[2rem] border border-artisan-clay bg-white p-8 text-center shadow-2xl">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-artisan-terracotta/10">
          <Lock className="h-6 w-6 text-artisan-terracotta" />
        </div>
        <h2
          id="subscription-gate-title"
          className="mt-5 font-serif text-2xl font-bold text-artisan-sienna"
        >
          Subscription required
        </h2>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">
          To keep uploading or editing products, you&apos;ll need an active Artisan Lane
          subscription. Your first two months are free, then it&apos;s R349/month with 0%
          commission on your sales.
        </p>
        <Button
          asChild
          className="mt-6 w-full rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90"
        >
          <Link href={SUBSCRIPTION_PATH}>Subscribe to continue</Link>
        </Button>
        <p className="mt-4 text-xs text-muted-foreground">
          Need help? Message us on WhatsApp using the support button.
        </p>
      </div>
    </div>
  );
}
