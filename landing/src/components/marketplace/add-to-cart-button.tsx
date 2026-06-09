"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { reserveGuestCartItem } from "@/lib/marketplace/cart-reservations";

import { useGuestCart } from "./guest-cart-provider";

type AddToCartButtonProps = {
  productId: string;
  variantId?: string | null;
  disabled?: boolean;
  isMadeToOrder?: boolean;
  customNote?: string | null;
  label?: string;
};

export function AddToCartButton({
  productId,
  variantId = null,
  disabled,
  isMadeToOrder = false,
  customNote = null,
  label,
}: AddToCartButtonProps) {
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

  const idleLabel = label ?? (isMadeToOrder ? "Order made to order" : "Add to cart");

  return (
    <Button
      type="button"
      size="lg"
      disabled={disabled || isReserving}
      aria-live="polite"
      className="h-12 w-full rounded-full"
      onClick={async () => {
        setReservationError(false);
        setIsReserving(true);
        try {
          // Made-to-order items are produced on demand and never reserve stock.
          if (!isMadeToOrder) {
            const currentQuantity = items.find(
              (item) =>
                item.productId === productId &&
                item.variantId === variantId &&
                !item.isMadeToOrder,
            )?.quantity ?? 0;
            await reserveGuestCartItem({
              productId,
              variantId,
              quantity: currentQuantity + 1,
            });
          }
          addItem({ productId, variantId, quantity: 1, isMadeToOrder, customNote });
          setHasAdded(true);
        } catch {
          setReservationError(true);
        } finally {
          setIsReserving(false);
        }
      }}
    >
      {isReserving
        ? "Reserving..."
        : reservationError
          ? "Out of stock"
          : hasAdded
            ? "Added to cart"
            : idleLabel}
    </Button>
  );
}
