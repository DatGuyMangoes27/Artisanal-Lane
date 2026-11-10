"use client";

import { useEffect, useState } from "react";

import { lastCheckoutOrderStorageKey } from "@/lib/marketplace/checkout-groups";
import {
  summarisePurchase,
  type PurchaseOrderRow,
  type PurchaseSummary,
} from "@/lib/marketplace/purchase-summary";
import { createClient } from "@/lib/supabase/browser";

type Fbq = (command: "track", event: string, params?: object, options?: object) => void;

/**
 * Sends the Meta Pixel "Purchase" event once per order when the buyer lands
 * back on the thank-you page from TradeSafe. Payment happens on TradeSafe's
 * site, so this page is where Meta can see the sale.
 */
export function PurchasePixel({
  eventId,
  value,
  contentIds,
  numItems,
}: {
  eventId: string;
  value: number;
  contentIds: string[];
  numItems: number;
}) {
  useEffect(() => {
    const key = `artisanLane:purchaseTracked:${eventId}`;
    try {
      if (window.localStorage.getItem(key)) return;
    } catch {
      // Storage blocked: still send it; Meta de-duplicates on eventID.
    }
    const fbq = (window as unknown as { fbq?: Fbq }).fbq;
    if (typeof fbq !== "function") return;
    fbq(
      "track",
      "Purchase",
      {
        value: Math.round(value * 100) / 100,
        currency: "ZAR",
        content_ids: contentIds,
        content_type: "product",
        num_items: numItems,
      },
      { eventID: eventId },
    );
    try {
      window.localStorage.setItem(key, "1");
    } catch {
      // Ignore.
    }
  }, [eventId, value, contentIds, numItems]);

  return null;
}

/**
 * Fallback for a one-shop checkout where TradeSafe sends the buyer back
 * without the order number: uses the order the browser remembered at
 * checkout and reads it with the buyer's own session.
 */
export function RememberedPurchasePixel() {
  const [purchase, setPurchase] = useState<
    (PurchaseSummary & { eventId: string }) | null
  >(null);

  useEffect(() => {
    let orderId: string | null = null;
    try {
      orderId = window.sessionStorage.getItem(lastCheckoutOrderStorageKey);
    } catch {
      orderId = null;
    }
    if (!orderId) return;
    let cancelled = false;
    void createClient()
      .from("orders")
      .select("id, status, total, shipping_cost, order_items(product_id, quantity)")
      .eq("id", orderId)
      .then(({ data }: { data: unknown[] | null }) => {
        const summary = summarisePurchase((data ?? []) as PurchaseOrderRow[]);
        if (!cancelled && summary && orderId) setPurchase({ ...summary, eventId: orderId });
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return purchase ? (
    <PurchasePixel
      eventId={purchase.eventId}
      value={purchase.value}
      contentIds={purchase.contentIds}
      numItems={purchase.numItems}
    />
  ) : null;
}
