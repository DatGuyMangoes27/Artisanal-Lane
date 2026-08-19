export type AdminPayoutOrderLike = {
  status: string;
  paymentProvider: string | null;
  paymentState: string | null;
  tradeSafeAllocationId: string | null;
};

const adminCompletableOrderStatuses = new Set(["shipped", "delivered", "completed"]);
const terminalNonPayoutStates = new Set([
  "CANCELLED",
  "FAILED",
  "EXPIRED",
  "REFUNDED",
  "DECLINED",
  "REJECTED",
]);

export function canAdminTriggerTradeSafePayout(order: AdminPayoutOrderLike) {
  const normalizedStatus = order.status.trim().toLowerCase();
  const normalizedPaymentState = order.paymentState?.trim().toUpperCase() ?? "";

  return order.paymentProvider?.trim().toLowerCase() === "tradesafe" &&
    adminCompletableOrderStatuses.has(normalizedStatus) &&
    Boolean(order.tradeSafeAllocationId?.trim()) &&
    normalizedPaymentState !== "FUNDS_RELEASED" &&
    !terminalNonPayoutStates.has(normalizedPaymentState);
}

export function tradeSafePayoutLabel(paymentState: string | null) {
  switch (paymentState?.trim().toUpperCase()) {
    case "FUNDS_RELEASED":
      return "Released";
    case "DELIVERED":
    case "DELIVERY_ACCEPTED":
    case "ACCEPTED":
      return "Payout instructed";
    case "FUNDS_RECEIVED":
      return "Held in escrow";
    default:
      return paymentState?.trim() || "Not ready";
  }
}
