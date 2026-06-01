"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { getPaymentResultOrderHref } from "@/lib/marketplace/payment-results";

type PaymentResultActionsProps = {
  fallbackHref: string;
  fallbackLabel: string;
  orderId?: string | null;
};

export function PaymentResultActions({
  fallbackHref,
  fallbackLabel,
  orderId,
}: PaymentResultActionsProps) {
  const [storedOrderId, setStoredOrderId] = useState<string | null>(null);
  const orderHref = getPaymentResultOrderHref(orderId ?? storedOrderId);

  useEffect(() => {
    const checkoutOrderId = window.sessionStorage.getItem("artisanLane:lastCheckoutOrderId");
    window.setTimeout(() => setStoredOrderId(checkoutOrderId), 0);
  }, []);

  return (
    <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
      {orderHref ? (
        <Button asChild size="lg" className="rounded-full">
          <Link href={orderHref}>View order</Link>
        </Button>
      ) : null}
      <Button asChild size="lg" variant={orderHref ? "outline" : "default"} className="rounded-full">
        <Link href={fallbackHref}>{fallbackLabel}</Link>
      </Button>
    </div>
  );
}
