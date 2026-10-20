import { parseCheckoutGroupStatus, type CheckoutGroupStatus } from "./checkout";

// A several-shop checkout is paid once (a TradeSafe wallet top-up for the
// whole basket). TradeSafe may not send the buyer back to us afterwards, so
// the website polls checkout-group-status until the shops are funded.

export const lastCheckoutGroupStorageKey = "artisanLane:lastCheckoutGroupId";
export const lastCheckoutOrderStorageKey = "artisanLane:lastCheckoutOrderId";

export const checkoutGroupPollIntervalMs = 4_000;
export const checkoutGroupPollTimeoutMs = 30 * 60 * 1_000;

export const supportEmail = "nicky@artisanlanesa.com";

export type CheckoutGroupState = {
  checkoutGroupId: string;
  status: CheckoutGroupStatus;
  orderIds: string[];
  paidOrderIds: string[];
  checkoutUrl: string | null;
};

function stringList(value: unknown) {
  return Array.isArray(value)
    ? value.filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0)
    : [];
}

/** Reads a checkout-group-status response; null when it is not usable. */
export function parseCheckoutGroupState(data: unknown): CheckoutGroupState | null {
  if (typeof data !== "object" || data == null) return null;
  const record = data as Record<string, unknown>;
  const status = parseCheckoutGroupStatus(record.status);
  const checkoutGroupId = typeof record.checkoutGroupId === "string" ? record.checkoutGroupId.trim() : "";
  if (!status || !checkoutGroupId) return null;

  return {
    checkoutGroupId,
    status,
    orderIds: stringList(record.orderIds),
    paidOrderIds: stringList(record.paidOrderIds),
    checkoutUrl:
      typeof record.checkoutUrl === "string" && record.checkoutUrl.trim().length > 0
        ? record.checkoutUrl.trim()
        : null,
  };
}

export function isFinalCheckoutGroupStatus(status: CheckoutGroupStatus) {
  return status !== "awaiting_payment";
}

export function checkoutGroupStatusCopy(status: CheckoutGroupStatus) {
  switch (status) {
    case "funded":
      return {
        title: "Payment received. Thank you!",
        body: "Each artisan has been told about their part of your order. You can follow every order below.",
      };
    case "cancelled":
      return {
        title: "This checkout expired",
        body:
          "This checkout expired before payment. Nothing was charged to the shops; if you paid, the money is in your TradeSafe wallet and will be used on your next checkout.",
      };
    case "needs_attention":
      return {
        title: "We're looking into your payment",
        body: `Your payment needs a quick check from our team before the shops can start on your order. We're on it. If you have questions, email ${supportEmail}.`,
      };
    default:
      return {
        title: "Waiting for your payment",
        body:
          "Finish paying on the TradeSafe page. This page updates by itself once your payment arrives, so please keep it open.",
      };
  }
}

/** Remembers the checkout so /payment/success can pick it up after a reload. */
export function rememberCheckoutGroup(checkoutGroupId: string, firstOrderId: string | null) {
  try {
    window.sessionStorage.setItem(lastCheckoutGroupStorageKey, checkoutGroupId);
    if (firstOrderId) {
      window.sessionStorage.setItem(lastCheckoutOrderStorageKey, firstOrderId);
    }
  } catch {
    // Storage can be unavailable (private mode); polling still works in-page.
  }
}

export function readRememberedCheckoutGroup() {
  try {
    return window.sessionStorage.getItem(lastCheckoutGroupStorageKey);
  } catch {
    return null;
  }
}

export function forgetRememberedCheckoutGroup() {
  try {
    window.sessionStorage.removeItem(lastCheckoutGroupStorageKey);
  } catch {
    // Nothing to forget.
  }
}

// Shared across tabs (TradeSafe may open in its own tab): the basket that is
// still waiting for payment, so whichever tab sees it paid clears the cart once.
const pendingCheckoutGroupStorageKey = "artisanLane:pendingCheckoutGroupId";

export function markPendingCheckoutGroup(checkoutGroupId: string) {
  try {
    window.localStorage.setItem(pendingCheckoutGroupStorageKey, checkoutGroupId);
  } catch {
    // The checkout tab still clears the cart itself.
  }
}

/** True once for the pending checkout: the caller should clear the cart now. */
export function takePendingCheckoutGroup(checkoutGroupId: string) {
  try {
    if (window.localStorage.getItem(pendingCheckoutGroupStorageKey) !== checkoutGroupId) {
      return false;
    }
    window.localStorage.removeItem(pendingCheckoutGroupStorageKey);
    return true;
  } catch {
    return false;
  }
}

export function successPageHrefForGroup(checkoutGroupId: string) {
  return `/payment/success?group=${encodeURIComponent(checkoutGroupId)}`;
}
