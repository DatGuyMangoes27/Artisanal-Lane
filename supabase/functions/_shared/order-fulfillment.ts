const tradeSafeDeliveryShippingMethods = new Set([
  "courier_guy",
  "courier_guy_door_to_door",
  "pargo",
]);

export function shouldStartTradeSafeDelivery(shippingMethod: string | null) {
  return shippingMethod != null &&
    tradeSafeDeliveryShippingMethods.has(shippingMethod);
}

export function shouldAcceptTradeSafeDelivery({
  allocationId,
}: {
  allocationId: string | null;
  shippingMethod: string | null;
}) {
  return allocationId != null && allocationId.trim().length > 0;
}
