"use client";

import { useEffect, useMemo, useState } from "react";

type AvailabilityLine = { productId: string; quantity: number };

/**
 * Asks the server whether Bob Go can be offered for these cart lines. Returns
 * false while the flag is off, while loading and on any error, so Bob Go is
 * only ever shown for carts that can actually be quoted.
 */
export function useBobGoAvailability(lines: AvailabilityLine[], flagEnabled: boolean) {
  const itemsKey = useMemo(
    () => JSON.stringify(lines.map((line) => ({ productId: line.productId, quantity: line.quantity }))),
    [lines],
  );
  const [result, setResult] = useState<{ key: string; available: boolean } | null>(null);

  useEffect(() => {
    if (!flagEnabled || itemsKey === "[]") return;
    let isCurrent = true;
    fetch("/api/marketplace/bobgo/availability/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items: JSON.parse(itemsKey) }),
    })
      .then((response) => (response.ok ? response.json() : null) as Promise<{ available?: boolean } | null>)
      .then((payload) => {
        if (isCurrent) setResult({ key: itemsKey, available: payload?.available === true });
      })
      .catch(() => {
        if (isCurrent) setResult({ key: itemsKey, available: false });
      });
    return () => {
      isCurrent = false;
    };
  }, [flagEnabled, itemsKey]);

  return flagEnabled && result?.key === itemsKey && result.available;
}
