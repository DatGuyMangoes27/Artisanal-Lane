export type GuestCartItem = {
  key: string;
  productId: string;
  variantId: string | null;
  quantity: number;
};

export type GuestCartItemInput = {
  productId: string;
  variantId: string | null;
  quantity?: number;
};

export function getGuestCartItemKey(productId: string, variantId: string | null) {
  return variantId ? `${productId}:${variantId}` : productId;
}

export function addGuestCartItem(
  items: GuestCartItem[],
  input: GuestCartItemInput,
): GuestCartItem[] {
  const quantity = Math.max(1, input.quantity ?? 1);
  const key = getGuestCartItemKey(input.productId, input.variantId);
  const existing = items.find((item) => item.key === key);

  if (!existing) {
    return [
      ...items,
      {
        key,
        productId: input.productId,
        variantId: input.variantId,
        quantity,
      },
    ];
  }

  return items.map((item) =>
    item.key === key ? { ...item, quantity: item.quantity + quantity } : item,
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
