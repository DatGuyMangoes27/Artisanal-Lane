import { getProductPrimaryImage } from "./format";
import type { SavedAddress } from "./buyer-preferences";
import type { GuestCartItem } from "./cart";
import type { MarketplaceProduct, MarketplaceVariant, ShippingOption } from "./types";

export type CartLine = {
  key: string;
  productId: string;
  variantId: string | null;
  title: string;
  variantName: string | null;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
  stockQty: number;
  image: string;
  shopId: string;
  shopName: string;
  shippingOptions: ShippingOption[];
  isAvailable: boolean;
};

export const multiShopCheckoutMessage =
  "Checkout currently supports one artisan shop per order. Please complete each shop separately.";

function findVariant(product: MarketplaceProduct, variantId: string | null): MarketplaceVariant | null {
  if (!variantId) {
    return null;
  }

  return product.variants.find((variant) => variant.id === variantId) ?? null;
}

export function buildCartLines(
  items: GuestCartItem[],
  products: MarketplaceProduct[],
): CartLine[] {
  const productsById = new Map(products.map((product) => [product.id, product]));

  return items
    .map((item) => {
      const product = productsById.get(item.productId);
      if (!product) {
        return null;
      }

      const variant = findVariant(product, item.variantId);
      const unitPrice = variant?.price ?? product.price;
      const stockQty = variant?.stockQty ?? product.stockQty;
      const image = variant?.images[0] ?? getProductPrimaryImage(product);

      return {
        key: item.key,
        productId: item.productId,
        variantId: item.variantId,
        title: product.title,
        variantName: variant?.displayName ?? null,
        quantity: item.quantity,
        unitPrice,
        lineTotal: unitPrice * item.quantity,
        stockQty,
        image,
        shopId: product.shopId,
        shopName: product.shop?.name ?? "Artisan Lane seller",
        shippingOptions: product.shippingOptions,
        isAvailable: item.quantity <= stockQty,
      };
    })
    .filter((line): line is CartLine => line != null);
}

export function getCartSubtotal(lines: CartLine[]) {
  return lines.reduce((total, line) => total + line.lineTotal, 0);
}

export function getCheckoutBlocker(lines: CartLine[]) {
  if (lines.length === 0) {
    return "Your cart is empty.";
  }

  if (lines.some((line) => !line.isAvailable)) {
    return "One or more cart items no longer has enough stock. Please update your cart before checkout.";
  }

  const shopIds = new Set(lines.map((line) => line.shopId));
  if (shopIds.size > 1) {
    return multiShopCheckoutMessage;
  }

  if (getAvailableShippingOptionsForCart(lines).length === 0) {
    return "The products in this cart do not share an available shipping option yet.";
  }

  return null;
}

export function getAvailableShippingOptionsForCart(lines: CartLine[]) {
  if (lines.length === 0) {
    return [];
  }

  const enabledByLine = lines.map((line) =>
    line.shippingOptions.filter((option) => option.enabled),
  );

  if (enabledByLine.some((options) => options.length === 0)) {
    return [];
  }

  return enabledByLine[0].filter((candidate) =>
    enabledByLine.every((options) =>
      options.some((option) => option.key === candidate.key),
    ),
  );
}

export function calculateShippingTotal(lines: CartLine[], methodKey: string) {
  return lines.reduce((total, line) => {
    const option = line.shippingOptions.find(
      (candidate) => candidate.key === methodKey && candidate.enabled,
    );

    if (!option) {
      throw new Error(`Shipping method ${methodKey} is not available.`);
    }

    return total + option.price * line.quantity;
  }, 0);
}

export function requiresShippingAddress(methodKey: string | null) {
  return methodKey === "courier_guy_door_to_door";
}

export function requiresPickupPoint(methodKey: string | null) {
  return methodKey === "courier_guy" || methodKey === "pargo";
}

export function getSavedAddressCheckoutFields(address: SavedAddress) {
  return {
    name: address.name,
    phone: address.phone,
    street: address.street,
    city: address.city,
    postalCode: address.postalCode,
    province: address.province,
  };
}
