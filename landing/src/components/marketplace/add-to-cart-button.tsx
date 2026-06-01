"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { reserveGuestCartItem } from "@/lib/marketplace/cart-reservations";

import { useGuestCart } from "./guest-cart-provider";

type AddToCartButtonProps = {
  productId: string;
  variantId?: string | null;
  disabled?: boolean;
};

export function AddToCartButton({ productId, variantId = null, disabled }: AddToCartButtonProps) {
  const { addItem, items } = useGuestCart();
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
      size="lg"
      disabled={disabled || isReserving}
      aria-live="polite"
      className="h-12 w-full rounded-full"
      onClick={async () => {
        setReservationError(false);
        const currentQuantity = items.find(
          (item) => item.productId === productId && item.variantId === variantId,
        )?.quantity ?? 0;
        setIsReserving(true);
        try {
          await reserveGuestCartItem({
            productId,
            variantId,
            quantity: currentQuantity + 1,
          });
          addItem({ productId, variantId, quantity: 1 });
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
