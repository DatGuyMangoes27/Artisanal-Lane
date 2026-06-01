"use client";

import { useState, useTransition } from "react";
import { Heart } from "lucide-react";

import { toggleFavouriteProductInline } from "@/app/account/actions";
import { Button } from "@/components/ui/button";

type ProductFavouriteButtonProps = {
  productId: string;
  initialIsFavourite?: boolean;
  redirectTo?: string;
};

export function ProductFavouriteButton({
  productId,
  initialIsFavourite = false,
  redirectTo = "/shop",
}: ProductFavouriteButtonProps) {
  const [isFavourite, setIsFavourite] = useState(initialIsFavourite);
  const [isPending, startTransition] = useTransition();

  function toggleFavourite() {
    const nextIsFavourite = !isFavourite;
    setIsFavourite(nextIsFavourite);

    startTransition(async () => {
      try {
        const result = await toggleFavouriteProductInline(productId, nextIsFavourite, redirectTo);

        if (result.redirectTo) {
          window.location.href = result.redirectTo;
          return;
        }

        setIsFavourite(result.isFavourite);
      } catch {
        setIsFavourite(!nextIsFavourite);
      }
    });
  }

  return (
    <Button
      type="button"
      variant="secondary"
      size="icon"
      aria-label={isFavourite ? "Remove from favourites" : "Add to favourites"}
      aria-pressed={isFavourite}
      disabled={isPending}
      onClick={toggleFavourite}
      className="size-9 rounded-full border border-artisan-clay/70 bg-card/90 text-artisan-terracotta shadow-sm backdrop-blur transition hover:bg-card"
    >
      <Heart className={isFavourite ? "fill-current" : undefined} />
    </Button>
  );
}
