export type LocalOrderStatus = "pending" | "paid" | "cancelled" | string;

export function mapTradeSafeOrderStatus(state: string) {
  switch (state) {
    case "FUNDS_RECEIVED":
      return "paid";
    case "FUNDS_RELEASED":
      return "completed";
    case "CANCELLED":
    case "FAILED":
    case "EXPIRED":
      return "cancelled";
    default:
      return "pending";
  }
}

export function mapTradeSafeEscrowStatus(state: string) {
  switch (state) {
    case "FUNDS_RECEIVED":
      return "held";
    case "FUNDS_RELEASED":
      return "released";
    case "CANCELLED":
    case "FAILED":
    case "EXPIRED":
      return "cancelled";
    default:
      return "pending";
  }
}

export function shouldIgnoreTradeSafeCallback({
  currentOrderStatus,
  currentPaymentState,
  incomingTradeSafeState,
}: {
  currentOrderStatus: LocalOrderStatus;
  currentPaymentState: string | null;
  incomingTradeSafeState: string;
}) {
  const incomingOrderStatus = mapTradeSafeOrderStatus(incomingTradeSafeState);
  const fulfilledLocalStatuses = new Set(["paid", "shipped", "delivered", "completed"]);

  if (
    fulfilledLocalStatuses.has(currentOrderStatus) &&
    incomingOrderStatus === "pending"
  ) {
    return true;
  }

  return currentOrderStatus === "cancelled" &&
    currentPaymentState === "STALE_CHECKOUT_CANCELLED" &&
    incomingTradeSafeState !== "CANCELLED" &&
    incomingTradeSafeState !== "FAILED" &&
    incomingTradeSafeState !== "EXPIRED";
}
