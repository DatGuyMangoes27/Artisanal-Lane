"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import type { CheckoutGroupStatus } from "@/lib/marketplace/checkout";
import {
  checkoutGroupPollIntervalMs,
  checkoutGroupPollTimeoutMs,
  checkoutGroupStatusCopy,
  isFinalCheckoutGroupStatus,
  parseCheckoutGroupState,
  supportEmail,
  type CheckoutGroupState,
} from "@/lib/marketplace/checkout-groups";
import { formatPrice } from "@/lib/marketplace/format";
import { getOrderShortId } from "@/lib/marketplace/orders";
import { getPaymentResultOrderHref } from "@/lib/marketplace/payment-results";
import { createClient } from "@/lib/supabase/browser";

type CheckoutGroupPaymentProps = {
  checkoutGroupId: string;
  initialStatus?: CheckoutGroupStatus;
  initialCheckoutUrl?: string | null;
  initialOrderIds?: string[];
  total?: number | null;
  /** Called once when the basket is paid. */
  onFunded?: (state: CheckoutGroupState) => void;
  /** List the paid orders here (false when the caller moves on to another page). */
  showOrdersWhenFunded?: boolean;
  /** Called once when the checkout ends any other way (expired or needs attention). */
  onSettled?: (state: CheckoutGroupState) => void;
};

/**
 * Waits for a several-shop basket payment. TradeSafe may not send the buyer
 * back after paying, so this polls checkout-group-status (which also funds
 * each shop once the money arrives) until the checkout is settled.
 */
export function CheckoutGroupPayment({
  checkoutGroupId,
  initialStatus = "awaiting_payment",
  initialCheckoutUrl = null,
  initialOrderIds = [],
  total = null,
  onFunded,
  onSettled,
  showOrdersWhenFunded = true,
}: CheckoutGroupPaymentProps) {
  const [state, setState] = useState<CheckoutGroupState>({
    checkoutGroupId,
    status: initialStatus,
    orderIds: initialOrderIds,
    paidOrderIds: [],
    checkoutUrl: initialCheckoutUrl,
  });
  const [isChecking, setIsChecking] = useState(false);
  const [checkError, setCheckError] = useState<string | null>(null);
  const [pollCount, setPollCount] = useState(0);
  const [hasOpenedPayment, setHasOpenedPayment] = useState(false);
  const [timedOut, setTimedOut] = useState(false);
  const startedAt = useRef(Date.now());
  const reportedStatus = useRef<CheckoutGroupStatus | null>(null);
  const onFundedRef = useRef(onFunded);
  const onSettledRef = useRef(onSettled);

  useEffect(() => {
    onFundedRef.current = onFunded;
    onSettledRef.current = onSettled;
  }, [onFunded, onSettled]);

  const checkStatus = useCallback(async () => {
    setIsChecking(true);
    try {
      const { data, error } = await createClient().functions.invoke("checkout-group-status", {
        body: { checkoutGroupId },
      });
      const next = parseCheckoutGroupState(data);
      if (error || !next) {
        throw new Error(
          (data as { error?: string } | null)?.error ?? "We could not check your payment just now.",
        );
      }
      setCheckError(null);
      setState((current) => ({
        ...next,
        // Keep the payment link we already have if the server stops sending it.
        checkoutUrl: next.checkoutUrl ?? (next.status === "awaiting_payment" ? current.checkoutUrl : null),
        orderIds: next.orderIds.length > 0 ? next.orderIds : current.orderIds,
      }));
    } catch (statusError) {
      setCheckError(
        statusError instanceof Error ? statusError.message : "We could not check your payment just now.",
      );
    } finally {
      setIsChecking(false);
      setPollCount((count) => count + 1);
    }
  }, [checkoutGroupId]);

  // Poll while the payment is outstanding, for up to 30 minutes.
  useEffect(() => {
    if (isFinalCheckoutGroupStatus(state.status) || timedOut) return;
    const elapsed = Date.now() - startedAt.current;
    if (elapsed >= checkoutGroupPollTimeoutMs) {
      setTimedOut(true);
      return;
    }
    // Check straight away on arrival, then every few seconds after each answer.
    const delay = pollCount === 0 ? 0 : checkoutGroupPollIntervalMs;
    const timer = window.setTimeout(() => void checkStatus(), delay);
    return () => window.clearTimeout(timer);
  }, [checkStatus, pollCount, state.status, timedOut]);

  useEffect(() => {
    if (!isFinalCheckoutGroupStatus(state.status) || reportedStatus.current === state.status) return;
    reportedStatus.current = state.status;
    if (state.status === "funded") {
      onFundedRef.current?.(state);
    } else {
      onSettledRef.current?.(state);
    }
  }, [state]);

  const copy = checkoutGroupStatusCopy(state.status);
  const showOrders = state.status === "funded" && showOrdersWhenFunded;

  return (
    <div className="rounded-[2rem] border border-artisan-clay bg-card p-6 text-left shadow-sm sm:p-8">
      <h2 className="font-serif text-3xl font-bold tracking-tight text-foreground">{copy.title}</h2>
      <p className="mt-3 leading-7 text-muted-foreground">{copy.body}</p>

      {state.status === "awaiting_payment" ? (
        <div className="mt-6 space-y-4">
          {total != null ? (
            <p className="text-sm text-muted-foreground">
              Amount to pay: <span className="font-semibold text-foreground">{formatPrice(total)}</span>
            </p>
          ) : null}
          <div className="flex flex-col gap-3 sm:flex-row">
            {state.checkoutUrl ? (
              <Button asChild size="lg" className="rounded-full">
                <a
                  href={state.checkoutUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={() => setHasOpenedPayment(true)}
                >
                  {hasOpenedPayment ? "Reopen payment page" : "Open TradeSafe payment page"}
                </a>
              </Button>
            ) : null}
            <Button
              type="button"
              size="lg"
              variant="outline"
              className="rounded-full"
              disabled={isChecking}
              onClick={() => {
                setTimedOut(false);
                startedAt.current = Date.now();
                void checkStatus();
              }}
            >
              {isChecking ? "Checking..." : "I've paid – check again"}
            </Button>
          </div>
          {timedOut ? (
            <p className="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
              We stopped checking automatically. If you have paid, tap &ldquo;I&apos;ve paid – check again&rdquo;.
            </p>
          ) : (
            <p className="text-sm text-muted-foreground">
              {isChecking ? "Checking for your payment..." : "We check for your payment every few seconds."}
            </p>
          )}
          {checkError ? (
            <p className="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{checkError}</p>
          ) : null}
          <p className="text-xs leading-5 text-muted-foreground">
            You pay once for your whole basket and TradeSafe holds each shop&apos;s share safely until
            your parcel arrives. TradeSafe takes whole rands; any change stays in your TradeSafe wallet
            for next time.
          </p>
        </div>
      ) : null}

      {showOrders ? (
        <ul className="mt-6 divide-y overflow-hidden rounded-2xl border border-artisan-clay bg-background">
          {state.orderIds.map((orderId, index) => (
            <li key={orderId} className="flex items-center justify-between gap-4 p-4 text-sm">
              <span>
                <span className="block font-semibold text-foreground">Order #{getOrderShortId(orderId)}</span>
                <span className="block text-muted-foreground">
                  Shop {index + 1} of {state.orderIds.length}
                </span>
              </span>
              <Link
                href={getPaymentResultOrderHref(orderId) ?? "/account/orders"}
                className="font-semibold text-artisan-terracotta hover:underline"
              >
                View order
              </Link>
            </li>
          ))}
        </ul>
      ) : null}

      {state.status === "needs_attention" ? (
        <Button asChild size="lg" variant="outline" className="mt-6 rounded-full">
          <a href={`mailto:${supportEmail}?subject=${encodeURIComponent("Checkout payment")}`}>Contact support</a>
        </Button>
      ) : null}

      {state.status === "cancelled" ? (
        <Button asChild size="lg" className="mt-6 rounded-full">
          <Link href="/cart">Back to your cart</Link>
        </Button>
      ) : null}
    </div>
  );
}
