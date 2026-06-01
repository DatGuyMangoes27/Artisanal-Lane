"use client";

import Link from "next/link";
import { ShoppingBag } from "lucide-react";
import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { getGuestCartQuantity } from "@/lib/marketplace/cart";
import {
  guestCartChangedEvent,
  type GuestCartChangedDetail,
} from "@/lib/marketplace/cart-ui-events";

import {
  deserializeGuestCartItems,
  guestCartStorageKey,
} from "./guest-cart-provider";

function readGuestCartQuantity() {
  return getGuestCartQuantity(
    deserializeGuestCartItems(window.localStorage.getItem(guestCartStorageKey)),
  );
}

export function FloatingCartNotice() {
  const [quantity, setQuantity] = useState(0);
  const [wasJustUpdated, setWasJustUpdated] = useState(false);

  useEffect(() => {
    queueMicrotask(() => setQuantity(readGuestCartQuantity()));

    function handleStorage(event: StorageEvent) {
      if (event.key === guestCartStorageKey) {
        setQuantity(readGuestCartQuantity());
      }
    }

    function handleCartChanged(event: Event) {
      const detail = (event as CustomEvent<GuestCartChangedDetail>).detail;
      setQuantity(detail.quantity);

      if (detail.showNotice) {
        setWasJustUpdated(true);
      }
    }

    window.addEventListener("storage", handleStorage);
    window.addEventListener(guestCartChangedEvent, handleCartChanged);
    return () => {
      window.removeEventListener("storage", handleStorage);
      window.removeEventListener(guestCartChangedEvent, handleCartChanged);
    };
  }, []);

  useEffect(() => {
    if (!wasJustUpdated) {
      return;
    }

    const timeout = window.setTimeout(() => setWasJustUpdated(false), 3600);
    return () => window.clearTimeout(timeout);
  }, [wasJustUpdated]);

  if (quantity <= 0) {
    return null;
  }

  return (
    <div className="fixed bottom-5 right-5 z-50 w-[calc(100vw-2.5rem)] max-w-sm rounded-[1.5rem] border border-artisan-clay bg-card/95 p-4 shadow-2xl shadow-artisan-terracotta/20 backdrop-blur">
      <div className="flex items-center gap-3">
        <div className="relative flex size-11 items-center justify-center rounded-full bg-artisan-terracotta text-white">
          <ShoppingBag className="size-5" />
          <span className="absolute -right-1 -top-1 flex size-5 items-center justify-center rounded-full bg-foreground text-[0.65rem] font-bold leading-none text-background">
            {quantity > 99 ? "99+" : quantity}
          </span>
        </div>
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-foreground">
            {wasJustUpdated ? "Added to cart" : "Your cart"}
          </p>
          <p className="text-sm text-muted-foreground">
            {quantity} {quantity === 1 ? "item" : "items"} ready for checkout.
          </p>
        </div>
        <Button asChild size="sm" className="rounded-full">
          <Link href="/cart">View</Link>
        </Button>
      </div>
    </div>
  );
}
