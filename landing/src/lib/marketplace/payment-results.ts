export type PaymentResultKind = "success" | "error";

export function getPaymentResultOrderHref(orderId: string | null | undefined) {
  const trimmed = orderId?.trim();
  return trimmed ? `/account/orders/${encodeURIComponent(trimmed)}` : null;
}

export function paymentResultStatusCopy(kind: PaymentResultKind) {
  if (kind === "success") {
    return {
      eyebrow: "Payment started",
      title: "Thanks, your order is being processed.",
      body:
        "TradeSafe will confirm the payment with Artisan Lane. You can continue browsing while the order updates.",
      primaryActionLabel: "Back to shop",
      primaryActionHref: "/shop",
    };
  }

  return {
    eyebrow: "Payment interrupted",
    title: "We could not complete payment.",
    body: "Your cart is still saved on this device. Review it and try TradeSafe checkout again.",
    primaryActionLabel: "Return to cart",
    primaryActionHref: "/cart",
  };
}
