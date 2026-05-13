export type BuyerOrderItem = {
  id: string;
  orderId: string;
  productId: string;
  variantId: string | null;
  title: string;
  variantName: string | null;
  image: string | null;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
};

export type BuyerOrder = {
  id: string;
  shortId: string;
  buyerId: string | null;
  shopId: string;
  shopName: string;
  shopSlug: string | null;
  status: string;
  total: number;
  shippingCost: number;
  shippingMethod: string | null;
  shippingAddress: Record<string, unknown> | null;
  trackingNumber: string | null;
  trackingUrl: string | null;
  paymentState: string;
  paymentProvider: string | null;
  paymentUrl: string | null;
  shippedAt: string | null;
  receivedAt: string | null;
  isGift: boolean;
  giftRecipient: string | null;
  giftMessage: string | null;
  createdAt: string;
  updatedAt: string;
  items: BuyerOrderItem[];
};

type JsonRecord = Record<string, unknown>;

function toRecord(value: unknown): JsonRecord | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonRecord)
    : null;
}

function toStringOrNull(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function toNumber(value: unknown, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  return fallback;
}

function toStringArray(value: unknown) {
  return Array.isArray(value) ? value.map(String) : [];
}

export function getOrderShortId(orderId: string) {
  return orderId.slice(0, 8).toUpperCase();
}

export function formatOrderStatus(status: string | null) {
  if (!status) {
    return "Unknown";
  }

  const formatted = status
    .split(/[_\s-]+/)
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  return formatted.charAt(0).toUpperCase() + formatted.slice(1);
}

export function formatShippingMethod(method: string | null) {
  switch (method) {
    case "courier_guy":
      return "Courier Guy Locker";
    case "courier_guy_door_to_door":
      return "Courier Guy Door to Door";
    case "pargo":
      return "Pargo";
    case "paxi":
      return "PAXI";
    case "market_pickup":
      return "Market Pickup";
    default:
      return method ? formatOrderStatus(method) : "Not selected";
  }
}

export function getOrderGrandTotal(order: Pick<BuyerOrder, "total" | "shippingCost" | "isGift">) {
  return order.total + order.shippingCost + (order.isGift ? 30 : 0);
}

export function getOrderPickupPointSummary(order: Pick<BuyerOrder, "shippingAddress">) {
  const pickupPoint = order.shippingAddress?.pickup_point;

  if (typeof pickupPoint === "string") {
    const trimmed = pickupPoint.trim();
    return trimmed.length > 0 ? trimmed : null;
  }

  const pickup = toRecord(pickupPoint);
  if (!pickup) {
    return null;
  }

  const parts = [
    toStringOrNull(pickup.name),
    toStringOrNull(pickup.code) ? `(${toStringOrNull(pickup.code)})` : null,
    toStringOrNull(pickup.address),
    toStringOrNull(pickup.province),
  ].filter(Boolean);

  return parts.length > 0 ? parts.join(" ").replace(" )", ")") : null;
}

export function mapBuyerOrder(row: JsonRecord): BuyerOrder {
  const shop = toRecord(row.shops);
  const items = Array.isArray(row.order_items) ? row.order_items : [];

  return {
    id: String(row.id),
    shortId: getOrderShortId(String(row.id)),
    buyerId: toStringOrNull(row.buyer_id),
    shopId: String(row.shop_id),
    shopName: toStringOrNull(shop?.name) ?? "Artisan Lane seller",
    shopSlug: toStringOrNull(shop?.slug),
    status: toStringOrNull(row.status) ?? "pending",
    total: toNumber(row.total),
    shippingCost: toNumber(row.shipping_cost),
    shippingMethod: toStringOrNull(row.shipping_method),
    shippingAddress: toRecord(row.shipping_address),
    trackingNumber: toStringOrNull(row.tracking_number),
    trackingUrl: toStringOrNull(row.tracking_url),
    paymentState: toStringOrNull(row.payment_state) ?? "created",
    paymentProvider: toStringOrNull(row.payment_provider),
    paymentUrl: toStringOrNull(row.payment_url),
    shippedAt: toStringOrNull(row.shipped_at),
    receivedAt: toStringOrNull(row.received_at),
    isGift: row.is_gift === true,
    giftRecipient: toStringOrNull(row.gift_recipient),
    giftMessage: toStringOrNull(row.gift_message),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
    items: items.map((item) => mapBuyerOrderItem(toRecord(item) ?? {})),
  };
}

function mapBuyerOrderItem(row: JsonRecord): BuyerOrderItem {
  const product = toRecord(row.products);
  const productImages = toStringArray(product?.images);
  const variantImage = toStringOrNull(row.variant_image);
  const quantity = Math.trunc(toNumber(row.quantity));
  const unitPrice = toNumber(row.unit_price);

  return {
    id: String(row.id),
    orderId: String(row.order_id),
    productId: String(row.product_id),
    variantId: toStringOrNull(row.variant_id),
    title: toStringOrNull(product?.title) ?? "Product",
    variantName: toStringOrNull(row.variant_name),
    image: variantImage ?? productImages[0] ?? null,
    quantity,
    unitPrice,
    lineTotal: unitPrice * quantity,
  };
}
