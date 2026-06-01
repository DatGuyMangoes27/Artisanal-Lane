"use client";

import { useMemo, useState } from "react";
import { Gift, Minus, PackageCheck, Plus, Sticker } from "lucide-react";

import { Button } from "@/components/ui/button";
import { createStationeryCheckout } from "@/app/vendor/actions";
import { formatPrice } from "@/lib/marketplace/format";
import { cn } from "@/lib/utils";

const stationeryCatalog = [
  {
    key: "gift_tag",
    name: "Gift tags",
    description: "Branded swing tags for parcels and gift orders.",
    unitPrice: 7,
    increment: 25,
    icon: Gift,
  },
  {
    key: "wrap_sheet",
    name: "Wrap sheets",
    description: "Printed tissue/wrap sheets for polished packaging.",
    unitPrice: 15,
    increment: 25,
    icon: PackageCheck,
  },
  {
    key: "sticker",
    name: "Stickers",
    description: "Logo stickers for boxes, envelopes, and care cards.",
    unitPrice: 4,
    increment: 50,
    icon: Sticker,
  },
];

export function VendorStationeryRequestForm({ disabled }: { disabled: boolean }) {
  const [quantities, setQuantities] = useState<Record<string, number>>({
    gift_tag: 0,
    wrap_sheet: 0,
    sticker: 0,
  });

  const items = useMemo(
    () =>
      stationeryCatalog
        .map((item) => ({
          key: item.key,
          name: item.name,
          quantity: quantities[item.key] ?? 0,
          unitPrice: item.unitPrice,
        }))
        .filter((item) => item.quantity > 0),
    [quantities],
  );
  const total = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
  const totalQuantity = items.reduce((sum, item) => sum + item.quantity, 0);

  function updateQuantity(key: string, nextQuantity: number) {
    setQuantities((current) => ({
      ...current,
      [key]: Math.max(0, nextQuantity),
    }));
  }

  return (
    <form action={createStationeryCheckout} className="grid gap-5">
      <input type="hidden" name="itemsJson" value={JSON.stringify(items)} />

      <div className="rounded-3xl border border-artisan-clay/70 bg-artisan-bone/35 p-4">
        <p className="text-sm font-semibold text-artisan-sienna">Secure PayFast checkout</p>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          Choose the branded stationery you need. Payment is collected online before the
          fulfilment team starts printing and packing.
        </p>
      </div>

      <div className="grid gap-3">
        {stationeryCatalog.map((item) => {
          const Icon = item.icon;
          const quantity = quantities[item.key] ?? 0;
          return (
            <div
              key={item.key}
              className={cn(
                "rounded-3xl border p-4 transition",
                quantity > 0
                  ? "border-artisan-terracotta bg-artisan-bone/40"
                  : "border-artisan-clay/70 bg-white",
              )}
            >
              <div className="flex gap-4">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-artisan-terracotta/10 text-artisan-terracotta">
                  <Icon className="h-5 w-5" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <p className="font-semibold text-artisan-sienna">{item.name}</p>
                      <p className="mt-1 text-sm text-muted-foreground">{item.description}</p>
                    </div>
                    <p className="text-sm font-semibold text-artisan-sienna">
                      {formatPrice(item.unitPrice)} each
                    </p>
                  </div>
                  <div className="mt-4 flex items-center justify-between gap-3">
                    <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">
                      Batch of {item.increment}
                    </p>
                    <div className="flex items-center gap-2">
                      <Button
                        type="button"
                        variant="outline"
                        size="icon-sm"
                        disabled={disabled || quantity === 0}
                        onClick={() => updateQuantity(item.key, quantity - item.increment)}
                      >
                        <Minus className="h-4 w-4" />
                      </Button>
                      <span className="w-12 text-center text-sm font-semibold text-artisan-sienna">
                        {quantity}
                      </span>
                      <Button
                        type="button"
                        variant="outline"
                        size="icon-sm"
                        disabled={disabled}
                        onClick={() => updateQuantity(item.key, quantity + item.increment)}
                      >
                        <Plus className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <textarea
        name="deliveryAddress"
        placeholder="Delivery address"
        className="min-h-24 rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
        disabled={disabled}
      />
      <textarea
        name="notes"
        placeholder="Notes for the fulfilment team"
        className="min-h-24 rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
        disabled={disabled}
      />

      <div className="rounded-3xl border border-artisan-clay/70 bg-white p-4">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">Selected items</span>
          <span className="font-semibold text-artisan-sienna">{totalQuantity}</span>
        </div>
        <div className="mt-2 flex items-center justify-between text-sm">
          <span className="text-muted-foreground">Estimated total</span>
          <span className="text-xl font-semibold text-artisan-sienna">{formatPrice(total)}</span>
        </div>
      </div>

      <Button
        className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90"
        disabled={disabled || items.length === 0}
      >
        {disabled ? "Save shop first" : items.length === 0 ? "Select stationery" : "Start PayFast checkout"}
      </Button>
    </form>
  );
}
