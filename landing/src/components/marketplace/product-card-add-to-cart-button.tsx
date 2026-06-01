"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { addGuestCartItem } from "@/lib/marketplace/cart";
import { reserveGuestCartItem } from "@/lib/marketplace/cart-reservations";
import { dispatchGuestCartChanged } from "@/lib/marketplace/cart-ui-events";

import {
  deserializeGuestCartItems,
  guestCartStorageKey,
  serializeGuestCartItems,
} from "./guest-cart-provider";

type ProductCardAddToCartButtonProps = {
  productId: string;
  disabled?: boolean;
};

export function ProductCardAddToCartButton({ productId, disabled }: ProductCardAddToCartButtonProps) {
  const [hasAdded, setHasAdded] = useState(false);
  const [isReserving, setIsReserving] = useState(false);
  const [reservationError, setReservationError] = useState(false);

  useEffect(() => {
    if (!hasAdded) {
      return;
    }

    const timeout = window.setTimeout(() => setHasAdded(false), 1800);
    return () => window.clearTimeout(timeout);
  }, [hasAdded]);

  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      disabled={disabled || isReserving}
      aria-live="polite"
      className="w-full rounded-full"
      onClick={async () => {
        setReservationError(false);
        const currentItems = deserializeGuestCartItems(window.localStorage.getItem(guestCartStorageKey));
        const nextItems = addGuestCartItem(currentItems, {
          productId,
          variantId: null,
          quantity: 1,
        });
        const nextItem = nextItems.find((item) => item.productId === productId && item.variantId === null);

        if (!nextItem) {
          return;
        }

        setIsReserving(true);
        try {
          await reserveGuestCartItem({
            productId,
            variantId: null,
            quantity: nextItem.quantity,
          });
          window.localStorage.setItem(guestCartStorageKey, serializeGuestCartItems(nextItems));
          dispatchGuestCartChanged(nextItems, { showNotice: true });
          setHasAdded(true);
        } catch {
          setReservationError(true);
        } finally {
          setIsReserving(false);
        }
      }}
    >
      {isReserving ? "Reserving..." : reservationError ? "Out of stock" : hasAdded ? "Added to cart" : "Add to cart"}
    </Button>
  );
}
