"use client";

import { useEffect, useMemo, useState } from "react";

type AvailabilityLine = { productId: string; quantity: number };

type AvailabilityShopLine = AvailabilityLine & { shopId: string };

/**
 * Bob Go availability for each shop in the basket (each artisan quotes their
 * own parcel). Returns the shop ids Bob Go can quote; empty while loading.
 */
export function useBobGoAvailabilityByShop(lines: AvailabilityShopLine[], flagEnabled: boolean) {
  const shopsKey = useMemo(() => {
    const byShop = new Map<string, AvailabilityLine[]>();
    for (const line of lines) {
      byShop.set(line.shopId, [
        ...(byShop.get(line.shopId) ?? []),
        { productId: line.productId, quantity: line.quantity },
      ]);
    }
    return JSON.stringify([...byShop.entries()]);
  }, [lines]);
  const [result, setResult] = useState<{ key: string; shopIds: string[] } | null>(null);

  useEffect(() => {
    if (!flagEnabled || shopsKey === "[]") return;
    let isCurrent = true;
    const shops = JSON.parse(shopsKey) as Array<[string, AvailabilityLine[]]>;
    Promise.all(
      shops.map(([shopId, items]) =>
        fetch("/api/marketplace/bobgo/availability/", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ items }),
        })
          .then((response) => (response.ok ? response.json() : null) as Promise<{ available?: boolean } | null>)
          .then((payload) => (payload?.available === true ? shopId : null))
          .catch(() => null),
      ),
    ).then((available) => {
      if (isCurrent) {
        setResult({ key: shopsKey, shopIds: available.filter((shopId): shopId is string => shopId != null) });
      }
    });
    return () => {
      isCurrent = false;
    };
  }, [flagEnabled, shopsKey]);

  return useMemo(
    () => new Set(flagEnabled && result?.key === shopsKey ? result.shopIds : []),
    [flagEnabled, result, shopsKey],
  );
}
