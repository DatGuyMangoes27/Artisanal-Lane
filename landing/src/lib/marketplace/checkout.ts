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
  combinedShippingEnabled: boolean;
  shippingOptions: ShippingOption[];
  isAvailable: boolean;
  isMadeToOrder: boolean;
  customNote: string | null;
  leadMinDays: number | null;
  leadMaxDays: number | null;
};

export type CheckoutField =
  | "fullName"
  | "streetAddress"
  | "city"
  | "postalCode"
  | "province"
  | "phoneNumber"
  | "shippingMethod"
  | "pickupPoint";

export type CheckoutFormSnapshot = {
  fullName: string;
  streetAddress: string;
  city: string;
  postalCode: string;
  province: string | null;
  phoneNumber: string;
  selectedShippingMethod: string | null;
  hasAvailableShippingMethods: boolean;
  requiresShippingAddress: boolean;
  requiresPickupPoint: boolean;
  pickupPoint: string;
};

/** Gift wrapping is charged per shop: each artisan wraps their own parcel. */
export const GIFT_SERVICE_FEE_PER_SHOP = 30;

export type ShopCartGroup = {
  shopId: string;
  shopName: string;
  lines: CartLine[];
  quantity: number;
  subtotal: number;
};

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
      const isMadeToOrder = item.isMadeToOrder === true;
      const baseUnitPrice = variant?.price ?? product.price;
      const unitPrice = isMadeToOrder
        ? product.madeToOrderPrice ?? baseUnitPrice
        : baseUnitPrice;
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
        combinedShippingEnabled: product.shop?.combinedShippingEnabled !== false,
        shippingOptions: product.shippingOptions,
        // Made-to-order lines are produced on demand, so they are not limited
        // by current inventory (capacity is enforced server-side at checkout).
        isAvailable: isMadeToOrder || item.quantity <= stockQty,
        isMadeToOrder,
        customNote: item.customNote ?? null,
        leadMinDays: isMadeToOrder ? product.leadMinDays : null,
        leadMaxDays: isMadeToOrder ? product.leadMaxDays : null,
      };
    })
    .filter((line): line is CartLine => line != null);
}

export function getCartSubtotal(lines: CartLine[]) {
  return lines.reduce((total, line) => total + line.lineTotal, 0);
}

/** Splits cart lines by shop, keeping shops (and lines) in first-added order. */
export function groupCartLinesByShop(lines: CartLine[]): ShopCartGroup[] {
  const groups = new Map<string, ShopCartGroup>();
  for (const line of lines) {
    const group = groups.get(line.shopId) ?? {
      shopId: line.shopId,
      shopName: line.shopName,
      lines: [],
      quantity: 0,
      subtotal: 0,
    };
    group.lines.push(line);
    group.quantity += line.quantity;
    group.subtotal += line.lineTotal;
    groups.set(line.shopId, group);
  }
  return [...groups.values()];
}

export function getCheckoutBlocker(
  lines: CartLine[],
  options: {
    /** True (for every shop, or per shop) when Bob Go can quote that shop's items. */
    allowDynamicShipping?: boolean | ((shopId: string) => boolean);
  } = {},
) {
  if (lines.length === 0) {
    return "Your cart is empty.";
  }

  if (lines.some((line) => !line.isAvailable)) {
    return "One or more cart items no longer has enough stock. Please update your cart before checkout.";
  }

  const shops = groupCartLinesByShop(lines);
  const allowsDynamicShipping = (shopId: string) =>
    typeof options.allowDynamicShipping === "function"
      ? options.allowDynamicShipping(shopId)
      : options.allowDynamicShipping === true;
  const stuckShop = shops.find(
    (shop) =>
      !allowsDynamicShipping(shop.shopId) && getAvailableShippingOptionsForCart(shop.lines).length === 0,
  );
  if (stuckShop) {
    return shops.length === 1
      ? "The products in this cart do not share an available shipping option yet."
      : `${stuckShop.shopName}: the products from this shop do not share a delivery option yet. Remove one of them to continue.`;
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
  const combineShipping = lines.every((line) => line.combinedShippingEnabled);

  return lines.reduce((total, line) => {
    const option = line.shippingOptions.find(
      (candidate) => candidate.key === methodKey && candidate.enabled,
    );

    if (!option) {
      throw new Error(`Shipping method ${methodKey} is not available.`);
    }

    return combineShipping
      ? Math.max(total, option.price)
      : total + option.price * line.quantity;
  }, 0);
}

export function requiresShippingAddress(methodKey: string | null) {
  return methodKey === "bobgo_door_to_door";
}

export function requiresPickupPoint(methodKey: string | null) {
  return methodKey === "courier_guy" || methodKey === "pargo";
}

export function getSavedAddressCheckoutFields(address: SavedAddress) {
  return {
    name: address.name,
    phone: address.phone,
    street: address.street,
    localArea: address.city,
    city: address.city,
    postalCode: address.postalCode,
    province: address.province,
  };
}

export function firstIncompleteCheckoutField(snapshot: CheckoutFormSnapshot): CheckoutField | null {
  if (snapshot.fullName.trim().length === 0) return "fullName";
  if (snapshot.requiresShippingAddress) {
    if (snapshot.streetAddress.trim().length === 0) return "streetAddress";
    if (snapshot.city.trim().length === 0) return "city";
    if (snapshot.postalCode.trim().length === 0) return "postalCode";
    if ((snapshot.province ?? "").trim().length === 0) return "province";
  }
  if (snapshot.phoneNumber.trim().length === 0) return "phoneNumber";
  if (!snapshot.hasAvailableShippingMethods || !snapshot.selectedShippingMethod?.trim()) {
    return "shippingMethod";
  }
  if (snapshot.requiresPickupPoint && snapshot.pickupPoint.trim().length === 0) {
    return "pickupPoint";
  }

  return null;
}

export function checkoutBlockingMessage(field: CheckoutField | null) {
  if (field === "pickupPoint") {
    return "Please enter the pickup point or drop-off location for this shipping method.";
  }
  if (field === "shippingMethod") {
    return "This product does not have any shipping options available yet.";
  }

  return "Please complete your checkout details before continuing to TradeSafe.";
}

export function getGiftFeeTotal(isGift: boolean, shopCount: number) {
  return isGift ? GIFT_SERVICE_FEE_PER_SHOP * shopCount : 0;
}

export type ShopCheckoutTotals = {
  shopId: string;
  shopName: string;
  subtotal: number;
  shippingCost: number;
  giftFee: number;
  total: number;
};

/** Per-shop and basket totals before any discount code (the server applies those). */
export function calculateCheckoutTotals(
  shops: Array<{ shopId: string; shopName: string; subtotal: number; shippingCost: number }>,
  isGift: boolean,
) {
  const perShop: ShopCheckoutTotals[] = shops.map((shop) => {
    const giftFee = getGiftFeeTotal(isGift, 1);
    return { ...shop, giftFee, total: shop.subtotal + shop.shippingCost + giftFee };
  });
  const sum = (pick: (shop: ShopCheckoutTotals) => number) =>
    perShop.reduce((total, shop) => total + pick(shop), 0);

  return {
    shops: perShop,
    subtotal: sum((shop) => shop.subtotal),
    shippingCost: sum((shop) => shop.shippingCost),
    giftFee: sum((shop) => shop.giftFee),
    total: sum((shop) => shop.total),
  };
}

export type ShopDeliverySelection = {
  shopId: string;
  shippingMethod: string;
  shippingCost: number;
  /** Merged over the top-level address for this shop's order (e.g. its own pickup point). */
  shippingAddress?: Record<string, unknown> | null;
  bobgo?: {
    quoteId: string | null;
    rateResponseId: number | null;
    providerSlug: string | null;
    serviceLevelCode: string | null;
  } | null;
};

export type CheckoutRequestInput = {
  userId: string;
  reservationToken: string | null;
  shippingAddress: Record<string, unknown>;
  shops: ShopDeliverySelection[];
  isGift: boolean;
  giftRecipient: string;
  giftMessage: string;
  couponCode: string;
};

/**
 * The create-checkout request body. Always sends one `shops` entry per shop;
 * a one-shop basket also keeps the original top-level delivery fields.
 */
export function buildCheckoutRequestBody(input: CheckoutRequestInput) {
  const shops = input.shops.map((shop) => {
    const isBobGo = shop.shippingMethod === "bobgo_door_to_door";
    return {
      shopId: shop.shopId,
      shippingMethod: shop.shippingMethod,
      shippingCost: shop.shippingCost,
      bobgoQuoteId: isBobGo ? shop.bobgo?.quoteId ?? null : null,
      bobgoRateResponseId: isBobGo ? shop.bobgo?.rateResponseId ?? null : null,
      bobgoProviderSlug: isBobGo ? shop.bobgo?.providerSlug ?? null : null,
      bobgoServiceLevelCode: isBobGo ? shop.bobgo?.serviceLevelCode ?? null : null,
      ...(shop.shippingAddress ? { shippingAddress: shop.shippingAddress } : {}),
    };
  });
  const singleShop = shops.length === 1 ? shops[0] : null;

  return {
    userId: input.userId,
    reservationToken: input.reservationToken,
    shippingAddress: input.shippingAddress,
    ...(singleShop
      ? {
          shippingMethod: singleShop.shippingMethod,
          shippingCost: singleShop.shippingCost,
          bobgoQuoteId: singleShop.bobgoQuoteId,
          bobgoRateResponseId: singleShop.bobgoRateResponseId,
          bobgoProviderSlug: singleShop.bobgoProviderSlug,
          bobgoServiceLevelCode: singleShop.bobgoServiceLevelCode,
        }
      : {}),
    shops,
    isGift: input.isGift,
    giftRecipient: input.isGift ? input.giftRecipient.trim() || null : null,
    giftMessage: input.isGift ? input.giftMessage.trim() || null : null,
    couponCode: input.couponCode.trim().toUpperCase() || null,
  };
}

export type CheckoutGroupStatus = "awaiting_payment" | "funded" | "cancelled" | "needs_attention";

export type CheckoutResult =
  | { kind: "single"; orderId: string | null; checkoutUrl: string }
  | {
      kind: "group";
      checkoutGroupId: string;
      status: CheckoutGroupStatus;
      orderIds: string[];
      checkoutUrl: string | null;
      total: number | null;
    }
  | { kind: "error"; message: string };

function nonEmptyString(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

export function parseCheckoutGroupStatus(value: unknown): CheckoutGroupStatus | null {
  return value === "awaiting_payment" || value === "funded" || value === "cancelled" || value === "needs_attention"
    ? value
    : null;
}

/** Reads either create-checkout response: one shop, or a several-shop checkout group. */
export function parseCheckoutResponse(data: unknown): CheckoutResult {
  const record = (typeof data === "object" && data != null ? data : {}) as Record<string, unknown>;
  const error = nonEmptyString(record.error);
  if (error) {
    return { kind: "error", message: error };
  }

  const checkoutGroupId = nonEmptyString(record.checkoutGroupId);
  if (checkoutGroupId) {
    const orderIds = Array.isArray(record.orderIds)
      ? record.orderIds.map(nonEmptyString).filter((id): id is string => id != null)
      : [];
    const firstOrderId = nonEmptyString(record.orderId);
    return {
      kind: "group",
      checkoutGroupId,
      status: parseCheckoutGroupStatus(record.status) ?? "awaiting_payment",
      orderIds: orderIds.length > 0 ? orderIds : firstOrderId ? [firstOrderId] : [],
      checkoutUrl: nonEmptyString(record.checkoutUrl),
      total: typeof record.total === "number" && Number.isFinite(record.total) ? record.total : null,
    };
  }

  const checkoutUrl = nonEmptyString(record.checkoutUrl);
  if (!checkoutUrl) {
    return { kind: "error", message: "Checkout failed." };
  }

  return { kind: "single", orderId: nonEmptyString(record.orderId), checkoutUrl };
}
