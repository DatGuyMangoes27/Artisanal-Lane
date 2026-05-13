export type BuyerDispute = {
  id: string;
  orderId: string;
  raisedBy: string;
  reason: string;
  status: string;
  resolution: string | null;
  conversationId: string | null;
};

export function canOpenDisputeForOrderStatus(status: string | null | undefined) {
  return status === "shipped" || status === "delivered";
}

export function sanitizeDisputeReason(value: FormDataEntryValue | string | null) {
  const trimmed = String(value ?? "").trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function formatDisputeStatus(status: string | null | undefined) {
  if (!status) return "Unknown";
  const label = status.replaceAll("_", " ").toLowerCase();
  return label.charAt(0).toUpperCase() + label.slice(1);
}
