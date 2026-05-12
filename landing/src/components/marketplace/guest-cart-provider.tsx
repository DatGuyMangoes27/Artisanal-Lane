"use client";

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import {
  addGuestCartItem,
  getGuestCartQuantity,
  type GuestCartItem,
  type GuestCartItemInput,
} from "../../lib/marketplace/cart";

export const guestCartStorageKey = "artisan-lane-guest-cart";

type GuestCartContextValue = {
  items: GuestCartItem[];
  quantity: number;
  addItem: (item: GuestCartItemInput) => void;
};

const GuestCartContext = createContext<GuestCartContextValue | null>(null);

function isGuestCartItem(value: unknown): value is GuestCartItem {
  if (value == null || typeof value !== "object") {
    return false;
  }

  const item = value as Partial<GuestCartItem>;

  return (
    typeof item.key === "string" &&
    typeof item.productId === "string" &&
    (typeof item.variantId === "string" || item.variantId === null) &&
    typeof item.quantity === "number" &&
    Number.isFinite(item.quantity) &&
    item.quantity > 0
  );
}

export function deserializeGuestCartItems(value: string | null): GuestCartItem[] {
  if (!value) {
    return [];
  }

  try {
    const parsed = JSON.parse(value) as unknown;
    return Array.isArray(parsed) ? parsed.filter(isGuestCartItem) : [];
  } catch {
    return [];
  }
}

export function serializeGuestCartItems(items: GuestCartItem[]) {
  return JSON.stringify(items);
}

export function GuestCartProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<GuestCartItem[]>([]);
  const hasLoadedStorage = useRef(false);

  useEffect(() => {
    const storedItems = deserializeGuestCartItems(window.localStorage.getItem(guestCartStorageKey));

    queueMicrotask(() => {
      hasLoadedStorage.current = true;
      setItems(storedItems);
    });
  }, []);

  useEffect(() => {
    if (!hasLoadedStorage.current) {
      return;
    }

    window.localStorage.setItem(guestCartStorageKey, serializeGuestCartItems(items));
  }, [items]);

  const value = useMemo<GuestCartContextValue>(
    () => ({
      items,
      quantity: getGuestCartQuantity(items),
      addItem: (item) => setItems((currentItems) => addGuestCartItem(currentItems, item)),
    }),
    [items],
  );

  return <GuestCartContext.Provider value={value}>{children}</GuestCartContext.Provider>;
}

export function useGuestCart() {
  const context = useContext(GuestCartContext);

  if (!context) {
    throw new Error("useGuestCart must be used within GuestCartProvider");
  }

  return context;
}
