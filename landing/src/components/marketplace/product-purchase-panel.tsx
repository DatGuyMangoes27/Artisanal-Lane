"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { formatPrice } from "@/lib/marketplace/format";
import type { MarketplaceProduct, MarketplaceVariant } from "@/lib/marketplace/types";

import { AddToCartButton } from "./add-to-cart-button";

type ProductPurchasePanelProps = {
  product: MarketplaceProduct;
  openMtoUnits: number;
  onVariantChange?: (variant: MarketplaceVariant | null) => void;
};

function leadTimeLabel(minDays: number | null, maxDays: number | null) {
  if (minDays == null && maxDays == null) return null;
  if (minDays != null && maxDays != null) {
    return minDays === maxDays ? `${minDays} days` : `${minDays}–${maxDays} days`;
  }
  return `${minDays ?? maxDays} days`;
}

function resolveVariant(
  product: MarketplaceProduct,
  selectedValues: string[],
): MarketplaceVariant | null {
  if (product.variants.length === 0) {
    return null;
  }

  if (product.optionGroups.length === 0) {
    // No structured option groups: each variant is selected directly by id.
    return product.variants.find((variant) => variant.id === selectedValues[0]) ?? null;
  }

  if (selectedValues.length !== product.optionGroups.length || selectedValues.some((value) => !value)) {
    return null;
  }

  return (
    product.variants.find(
      (variant) =>
        variant.optionValues.length === selectedValues.length &&
        variant.optionValues.every((value, index) => value === selectedValues[index]),
    ) ?? null
  );
}

export function ProductPurchasePanel({ product, openMtoUnits, onVariantChange }: ProductPurchasePanelProps) {
  const hasOptionGroups = product.optionGroups.length > 0;
  const hasVariants = product.variants.length > 0;

  const [selectedValues, setSelectedValues] = useState<string[]>(
    hasOptionGroups ? product.optionGroups.map(() => "") : [],
  );
  const [selectedVariantId, setSelectedVariantId] = useState<string>("");
  const [customNote, setCustomNote] = useState("");

  const onVariantChangeRef = useRef(onVariantChange);
  onVariantChangeRef.current = onVariantChange;

  const selectedVariant = useMemo(() => {
    if (!hasVariants) return null;
    if (hasOptionGroups) {
      return resolveVariant(product, selectedValues);
    }
    return product.variants.find((variant) => variant.id === selectedVariantId) ?? null;
  }, [hasVariants, hasOptionGroups, product, selectedValues, selectedVariantId]);

  useEffect(() => {
    onVariantChangeRef.current?.(selectedVariant);
  }, [selectedVariant]);

  const variantChosen = !hasVariants || selectedVariant != null;
  const effectiveStock = selectedVariant
    ? selectedVariant.stockQty
    : hasVariants
      ? 0
      : product.stockQty;
  const inStock = effectiveStock > 0;

  const mtoEnabled =
    product.fulfillmentMode === "made_to_order" || product.fulfillmentMode === "stocked_with_mto";
  const isMtoMode = mtoEnabled && (product.fulfillmentMode === "made_to_order" || !inStock);
  const capacityFull =
    isMtoMode &&
    product.madeToOrderCapacity != null &&
    openMtoUnits >= product.madeToOrderCapacity;
  const soldOut = !inStock && !mtoEnabled;

  const basePrice = selectedVariant?.price ?? product.price;
  const unitPrice = isMtoMode ? product.madeToOrderPrice ?? basePrice : basePrice;
  const lead = leadTimeLabel(product.leadMinDays, product.leadMaxDays);

  const showCustomNote = isMtoMode && product.allowCustomNote && variantChosen && !capacityFull;

  return (
    <div className="space-y-4">
      {hasVariants ? (
        <div className="space-y-3">
          {hasOptionGroups ? (
            product.optionGroups.map((group, groupIndex) => (
              <div key={group.name} className="space-y-2">
                <p className="text-sm font-semibold text-foreground">{group.name}</p>
                <div className="flex flex-wrap gap-2">
                  {group.values.map((value) => {
                    const isSelected = selectedValues[groupIndex] === value;
                    return (
                      <button
                        key={value}
                        type="button"
                        onClick={() =>
                          setSelectedValues((current) => {
                            const next = [...current];
                            next[groupIndex] = isSelected ? "" : value;
                            return next;
                          })
                        }
                        className={`rounded-full border px-4 py-2 text-sm font-medium transition ${
                          isSelected
                            ? "border-artisan-terracotta bg-artisan-terracotta text-white"
                            : "border-artisan-clay bg-white text-foreground hover:border-artisan-terracotta"
                        }`}
                      >
                        {value}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))
          ) : (
            <div className="space-y-2">
              <p className="text-sm font-semibold text-foreground">Options</p>
              <div className="flex flex-wrap gap-2">
                {product.variants.map((variant) => {
                  const isSelected = selectedVariantId === variant.id;
                  return (
                    <button
                      key={variant.id}
                      type="button"
                      onClick={() => setSelectedVariantId(isSelected ? "" : variant.id)}
                      className={`rounded-full border px-4 py-2 text-sm font-medium transition ${
                        isSelected
                          ? "border-artisan-terracotta bg-artisan-terracotta text-white"
                          : "border-artisan-clay bg-white text-foreground hover:border-artisan-terracotta"
                      }`}
                    >
                      {variant.displayName}
                    </button>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      ) : null}

      {isMtoMode && !capacityFull ? (
        <div className="rounded-2xl border border-artisan-terracotta/40 bg-artisan-bone/60 p-4 text-sm">
          <p className="font-semibold text-artisan-terracotta">Made to order</p>
          <p className="mt-1 text-muted-foreground">
            {lead
              ? `Hand-made just for you — ships in ${lead}.`
              : "Hand-made to order just for you."}
          </p>
          <p className="mt-2 text-base font-semibold text-foreground">{formatPrice(unitPrice)}</p>
        </div>
      ) : null}

      {showCustomNote ? (
        <label className="block text-sm font-medium text-foreground">
          Custom request (optional)
          <textarea
            value={customNote}
            onChange={(event) => setCustomNote(event.target.value)}
            rows={3}
            maxLength={500}
            placeholder="Tell the maker about colours, sizing, personalisation…"
            className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
          />
        </label>
      ) : null}

      {!variantChosen ? (
        <AddToCartButton productId={product.id} disabled label="Select options" />
      ) : soldOut ? (
        <AddToCartButton productId={product.id} disabled label="Sold out" />
      ) : capacityFull ? (
        <AddToCartButton productId={product.id} disabled label="Fully booked" />
      ) : (
        <AddToCartButton
          productId={product.id}
          variantId={selectedVariant?.id ?? null}
          isMadeToOrder={isMtoMode}
          customNote={isMtoMode ? customNote : null}
        />
      )}
    </div>
  );
}
