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

export function CartNavButton() {
  const [quantity, setQuantity] = useState(0);

  useEffect(() => {
    queueMicrotask(() => setQuantity(readGuestCartQuantity()));

    function handleStorage(event: StorageEvent) {
      if (event.key === guestCartStorageKey) {
        setQuantity(readGuestCartQuantity());
      }
    }

    function handleCartChanged(event: Event) {
      setQuantity((event as CustomEvent<GuestCartChangedDetail>).detail.quantity);
    }

    window.addEventListener("storage", handleStorage);
    window.addEventListener(guestCartChangedEvent, handleCartChanged);
    return () => {
      window.removeEventListener("storage", handleStorage);
      window.removeEventListener(guestCartChangedEvent, handleCartChanged);
    };
  }, []);

  return (
    <Button asChild variant="ghost" size="icon" aria-label={`Cart with ${quantity} items`}>
      <Link href="/cart" className="relative">
        <ShoppingBag />
        {quantity > 0 ? (
          <span className="absolute -right-1 -top-1 flex size-5 items-center justify-center rounded-full bg-artisan-terracotta text-[0.65rem] font-bold leading-none text-white">
            {quantity > 99 ? "99+" : quantity}
          </span>
        ) : null}
      </Link>
    </Button>
  );
}
