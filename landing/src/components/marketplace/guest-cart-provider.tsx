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
  removeGuestCartItem,
  updateGuestCartQuantity,
  type GuestCartItem,
  type GuestCartItemInput,
} from "../../lib/marketplace/cart";
import { dispatchGuestCartChanged } from "../../lib/marketplace/cart-ui-events";

export const guestCartStorageKey = "artisan-lane-guest-cart";

type GuestCartContextValue = {
  items: GuestCartItem[];
  quantity: number;
  addItem: (item: GuestCartItemInput) => void;
  updateItemQuantity: (key: string, quantity: number) => void;
  removeItem: (key: string) => void;
  clearCart: () => void;
};

const GuestCartContext = createContext<GuestCartContextValue | null>(null);

function isStoredGuestCartItem(
  value: unknown,
): value is Partial<GuestCartItem> & Pick<GuestCartItem, "key" | "productId" | "variantId" | "quantity"> {
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
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed.filter(isStoredGuestCartItem).map((item) => ({
      key: item.key,
      productId: item.productId,
      variantId: item.variantId,
      quantity: item.quantity,
      isMadeToOrder: item.isMadeToOrder === true,
      customNote: typeof item.customNote === "string" ? item.customNote : null,
    }));
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
      addItem: (item) =>
        setItems((currentItems) => {
          const nextItems = addGuestCartItem(currentItems, item);
          dispatchGuestCartChanged(nextItems, { showNotice: true });
          return nextItems;
        }),
      updateItemQuantity: (key, quantity) =>
        setItems((currentItems) => {
          const nextItems = updateGuestCartQuantity(currentItems, key, quantity);
          dispatchGuestCartChanged(nextItems);
          return nextItems;
        }),
      removeItem: (key) =>
        setItems((currentItems) => {
          const nextItems = removeGuestCartItem(currentItems, key);
          dispatchGuestCartChanged(nextItems);
          return nextItems;
        }),
      clearCart: () => {
        dispatchGuestCartChanged([]);
        setItems([]);
      },
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
