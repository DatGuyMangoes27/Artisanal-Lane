"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

import { useGuestCart } from "@/components/marketplace/guest-cart-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { buildCartLines, getCartSubtotal, getCheckoutBlocker } from "@/lib/marketplace/checkout";
import { formatPrice } from "@/lib/marketplace/format";
import type { MarketplaceProduct } from "@/lib/marketplace/types";

export function CartReview() {
  const { items, quantity, updateItemQuantity, removeItem } = useGuestCart();
  const [products, setProducts] = useState<MarketplaceProduct[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isCurrent = true;

    fetch("/api/marketplace/cart", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items }),
    })
      .then((response) => response.json() as Promise<{ products: MarketplaceProduct[] }>)
      .then((payload) => {
        if (isCurrent) {
          setProducts(payload.products);
        }
      })
      .finally(() => {
        if (isCurrent) {
          setIsLoading(false);
        }
      });

    return () => {
      isCurrent = false;
    };
  }, [items]);

  const lines = useMemo(() => buildCartLines(items, products), [items, products]);
  const subtotal = getCartSubtotal(lines);
  const blocker = getCheckoutBlocker(lines);

  if (quantity === 0) {
    return (
      <section className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          Guest cart
        </p>
        <h1 className="mt-4 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
          Your cart is empty.
        </h1>
        <p className="mt-4 text-muted-foreground">
          Browse the marketplace and save pieces from your favourite artisans.
        </p>
        <Button asChild size="lg" className="mt-8 rounded-full">
          <Link href="/shop">Continue shopping</Link>
        </Button>
      </section>
    );
  }

  return (
    <section className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[1fr_380px] lg:px-8">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          Guest cart
        </p>
        <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
          Review your cart
        </h1>
        <div className="mt-8 space-y-4">
          {isLoading ? (
            <Card className="border-artisan-clay bg-card">
              <CardContent className="p-6 text-muted-foreground">Loading your cart...</CardContent>
            </Card>
          ) : null}
          {lines.map((line) => (
            <Card key={line.key} className="border-artisan-clay bg-card">
              <CardContent className="grid gap-4 p-4 sm:grid-cols-[120px_1fr]">
                <div className="relative aspect-square overflow-hidden rounded-2xl bg-secondary">
                  <Image src={line.image} alt={line.title} fill sizes="120px" className="object-cover" />
                </div>
                <div className="flex flex-col justify-between gap-4">
                  <div>
                    <p className="text-sm text-muted-foreground">{line.shopName}</p>
                    <h2 className="mt-1 text-lg font-semibold text-foreground">{line.title}</h2>
                    {line.variantName ? (
                      <p className="mt-1 text-sm text-muted-foreground">{line.variantName}</p>
                    ) : null}
                    {!line.isAvailable ? (
                      <p className="mt-2 text-sm font-medium text-red-700">
                        Only {line.stockQty} available. Please lower the quantity.
                      </p>
                    ) : null}
                  </div>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                      <Button
                        type="button"
                        variant="outline"
                        size="icon-sm"
                        aria-label={`Decrease ${line.title} quantity`}
                        onClick={() => updateItemQuantity(line.key, line.quantity - 1)}
                      >
                        -
                      </Button>
                      <span className="min-w-8 text-center text-sm font-semibold">{line.quantity}</span>
                      <Button
                        type="button"
                        variant="outline"
                        size="icon-sm"
                        aria-label={`Increase ${line.title} quantity`}
                        onClick={() => updateItemQuantity(line.key, line.quantity + 1)}
                      >
                        +
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        className="text-muted-foreground"
                        onClick={() => removeItem(line.key)}
                      >
                        Remove
                      </Button>
                    </div>
                    <p className="font-semibold text-foreground">{formatPrice(line.lineTotal)}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      <aside className="h-fit rounded-[2rem] border border-artisan-clay bg-card p-6 shadow-sm">
        <h2 className="font-serif text-2xl font-bold text-foreground">Order summary</h2>
        <div className="mt-6 space-y-3 text-sm">
          <div className="flex justify-between">
            <span className="text-muted-foreground">Items</span>
            <span className="font-medium text-foreground">{quantity}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Subtotal</span>
            <span className="font-semibold text-foreground">{formatPrice(subtotal)}</span>
          </div>
        </div>
        {blocker ? (
          <p className="mt-5 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
            {blocker}
          </p>
        ) : null}
        <Button asChild size="lg" className="mt-6 w-full rounded-full" disabled={Boolean(blocker)}>
          <Link href={blocker ? "/cart" : "/checkout"}>Continue to checkout</Link>
        </Button>
        <Button asChild variant="ghost" className="mt-2 w-full rounded-full">
          <Link href="/shop">Keep shopping</Link>
        </Button>
      </aside>
    </section>
  );
}
