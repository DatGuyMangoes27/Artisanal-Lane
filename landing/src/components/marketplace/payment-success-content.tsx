"use client";

import { useEffect, useState } from "react";

import { CheckoutGroupPayment } from "@/components/marketplace/checkout-group-payment";
import { GuestCartProvider, useGuestCart } from "@/components/marketplace/guest-cart-provider";
import { PaymentResultActions } from "@/components/marketplace/payment-result-actions";
import { clearGuestCartReservationToken } from "@/lib/marketplace/cart-reservations";
import {
  forgetRememberedCheckoutGroup,
  readRememberedCheckoutGroup,
  takePendingCheckoutGroup,
} from "@/lib/marketplace/checkout-groups";
import { paymentResultStatusCopy } from "@/lib/marketplace/payment-results";

type PaymentSuccessContentProps = {
  orderId?: string | null;
  checkoutGroupId?: string | null;
};

/**
 * /payment/success for both checkouts: one shop (TradeSafe sent the buyer
 * back) and several shops (wait for the basket payment, then list orders).
 */
export function PaymentSuccessContent(props: PaymentSuccessContentProps) {
  return (
    <GuestCartProvider>
      <PaymentSuccessInner {...props} />
    </GuestCartProvider>
  );
}

function PaymentSuccessInner({ orderId, checkoutGroupId }: PaymentSuccessContentProps) {
  const { clearCart } = useGuestCart();
  // A one-shop return carries its order id; only fall back to a remembered
  // several-shop checkout when there is neither a group nor an order id.
  const [groupId, setGroupId] = useState<string | null | undefined>(
    checkoutGroupId?.trim() || (orderId?.trim() ? null : undefined),
  );
  const copy = paymentResultStatusCopy("success");

  useEffect(() => {
    if (groupId !== undefined) return;
    const remembered = readRememberedCheckoutGroup();
    window.setTimeout(() => setGroupId(remembered), 0);
  }, [groupId]);

  if (groupId === undefined) {
    return <p className="mt-8 text-muted-foreground">Checking your payment...</p>;
  }

  if (!groupId) {
    return (
      <>
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          {copy.eyebrow}
        </p>
        <h1 className="mt-4 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
          {copy.title}
        </h1>
        <p className="mt-4 leading-7 text-muted-foreground">{copy.body}</p>
        <PaymentResultActions
          fallbackHref={copy.primaryActionHref}
          fallbackLabel={copy.primaryActionLabel}
          orderId={orderId}
        />
      </>
    );
  }

  return (
    <>
      <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
        Your basket
      </p>
      <div className="mt-6">
        <CheckoutGroupPayment
          checkoutGroupId={groupId}
          onSettled={(state) => {
            if (state.status === "cancelled") {
              // The basket stays in the cart so the buyer can try again.
              takePendingCheckoutGroup(state.checkoutGroupId);
              forgetRememberedCheckoutGroup();
            }
          }}
          onFunded={(state) => {
            if (takePendingCheckoutGroup(state.checkoutGroupId)) {
              clearCart();
              clearGuestCartReservationToken();
            }
          }}
        />
      </div>
    </>
  );
}
