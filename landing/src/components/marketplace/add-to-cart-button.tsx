"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";

import { useGuestCart } from "./guest-cart-provider";

type AddToCartButtonProps = {
  productId: string;
  variantId?: string | null;
  disabled?: boolean;
};

export function AddToCartButton({ productId, variantId = null, disabled }: AddToCartButtonProps) {
  const { addItem } = useGuestCart();
  const [hasAdded, setHasAdded] = useState(false);

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
      disabled={disabled}
      aria-live="polite"
      className="h-12 w-full rounded-full"
      onClick={() => {
        addItem({ productId, variantId, quantity: 1 });
        setHasAdded(true);
      }}
    >
      {hasAdded ? "Added to cart" : "Add to cart"}
    </Button>
  );
}
