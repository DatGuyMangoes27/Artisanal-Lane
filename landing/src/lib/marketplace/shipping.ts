// Shared catalogue of supported shipping methods. Mirrors the mobile app's
// ShippingOption catalogue in lib/models/shipping_option.dart — keep both in sync.

export const SHIPPING_METHOD_KEYS = [
  "courier_guy",
  "courier_guy_door_to_door",
  "pargo",
  "market_pickup",
] as const;

export type ShippingMethodKey = (typeof SHIPPING_METHOD_KEYS)[number];

type ShippingMethodMeta = {
  name: string;
  description: string;
  defaultPrice: number;
};

const shippingMethodCatalogue: Record<ShippingMethodKey, ShippingMethodMeta> = {
  courier_guy: {
    name: "Courier Guy Locker",
    description: "Collect at a Courier Guy locker near you",
    defaultPrice: 69,
  },
  courier_guy_door_to_door: {
    name: "Courier Guy Door to Door",
    description: "Courier delivery to your address, 2–4 business days",
    defaultPrice: 110,
  },
  pargo: {
    name: "Pargo",
    description: "Pick up at a Pargo point near you",
    defaultPrice: 65,
  },
  market_pickup: {
    name: "Market Pickup",
    description: "Collect from the artisan in person",
    defaultPrice: 0,
  },
};

export function isKnownShippingMethod(key: string): key is ShippingMethodKey {
  return Object.prototype.hasOwnProperty.call(shippingMethodCatalogue, key);
}

export function shippingMethodName(key: string) {
  return isKnownShippingMethod(key) ? shippingMethodCatalogue[key].name : key.replaceAll("_", " ");
}

export function shippingMethodDescription(key: string) {
  return isKnownShippingMethod(key) ? shippingMethodCatalogue[key].description : "";
}

export function defaultShippingPrice(key: string) {
  return isKnownShippingMethod(key) ? shippingMethodCatalogue[key].defaultPrice : 0;
}
