export type GuestCartItem = {
  key: string;
  productId: string;
  variantId: string | null;
  quantity: number;
  isMadeToOrder: boolean;
  customNote: string | null;
};

export type GuestCartItemInput = {
  productId: string;
  variantId: string | null;
  quantity?: number;
  isMadeToOrder?: boolean;
  customNote?: string | null;
};

export function getGuestCartItemKey(
  productId: string,
  variantId: string | null,
  isMadeToOrder = false,
) {
  const base = variantId ? `${productId}:${variantId}` : productId;
  return isMadeToOrder ? `${base}:mto` : base;
}

export function addGuestCartItem(
  items: GuestCartItem[],
  input: GuestCartItemInput,
): GuestCartItem[] {
  const quantity = Math.max(1, input.quantity ?? 1);
  const isMadeToOrder = input.isMadeToOrder === true;
  const customNote = input.customNote?.trim() ? input.customNote.trim() : null;
  const key = getGuestCartItemKey(input.productId, input.variantId, isMadeToOrder);
  const existing = items.find((item) => item.key === key);

  if (!existing) {
    return [
      ...items,
      {
        key,
        productId: input.productId,
        variantId: input.variantId,
        quantity,
        isMadeToOrder,
        customNote,
      },
    ];
  }

  return items.map((item) =>
    item.key === key
      ? { ...item, quantity: item.quantity + quantity, customNote: customNote ?? item.customNote }
      : item,
  );
}

export function updateGuestCartQuantity(
  items: GuestCartItem[],
  key: string,
  quantity: number,
) {
  if (quantity <= 0) return removeGuestCartItem(items, key);
  return items.map((item) => (item.key === key ? { ...item, quantity } : item));
}

export function removeGuestCartItem(items: GuestCartItem[], key: string) {
  return items.filter((item) => item.key !== key);
}

export function getGuestCartQuantity(items: GuestCartItem[]) {
  return items.reduce((total, item) => total + item.quantity, 0);
}
