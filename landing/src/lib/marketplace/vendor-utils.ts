export type VendorSubscriptionLike = {
  status: string | null;
  currentPeriodEnd: string | null;
};

export type VendorPayoutLike = {
  accountHolderName?: string | null;
  bankName?: string | null;
  accountNumber?: string | null;
  branchCode?: string | null;
  accountType?: string | null;
  registeredPhone?: string | null;
  registeredEmail?: string | null;
  identityNumber?: string | null;
  verificationStatus?: string | null;
};

export type VendorSetupStatus = {
  canAddProducts: boolean;
  missingSteps: string[];
};

const activeSubscriptionStatuses = new Set(["active", "trialing"]);

function hasText(value: string | null | undefined) {
  return typeof value === "string" && value.trim().length > 0;
}

export function formatVendorStatus(status: string | null | undefined) {
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

export function isVendorSubscriptionActive(subscription: VendorSubscriptionLike | null | undefined) {
  if (!subscription?.status) {
    return false;
  }

  const normalized = subscription.status.toLowerCase();
  if (activeSubscriptionStatuses.has(normalized)) {
    return true;
  }

  if (normalized === "cancelled" && subscription.currentPeriodEnd) {
    return new Date(subscription.currentPeriodEnd).getTime() > Date.now();
  }

  return false;
}

export function isVendorPayoutReady(payout: VendorPayoutLike | null | undefined) {
  if (!payout) {
    return false;
  }

  return (
    hasText(payout.accountHolderName) &&
    hasText(payout.bankName) &&
    hasText(payout.accountNumber) &&
    hasText(payout.branchCode) &&
    hasText(payout.accountType) &&
    hasText(payout.registeredPhone) &&
    hasText(payout.registeredEmail) &&
    hasText(payout.identityNumber) &&
    payout.verificationStatus !== "action_required"
  );
}

export function isVendorShopProfileComplete(
  shop:
    | {
        name?: string | null;
        bio?: string | null;
        location?: string | null;
        shippingOptions?: unknown[] | null;
      }
    | null
    | undefined,
) {
  return (
    hasText(shop?.name) &&
    hasText(shop?.bio) &&
    hasText(shop?.location) &&
    Array.isArray(shop?.shippingOptions) &&
    shop.shippingOptions.length > 0
  );
}

export function getVendorSetupStatus({
  hasShop,
  payoutReady,
  subscriptionActive,
}: {
  hasShop: boolean;
  payoutReady: boolean;
  subscriptionActive: boolean;
}): VendorSetupStatus {
  const missingSteps = [
    hasShop ? null : "Shop profile",
    payoutReady ? null : "Payout details",
    subscriptionActive ? null : "Subscription",
  ].filter((step): step is string => Boolean(step));

  return {
    canAddProducts: missingSteps.length === 0,
    missingSteps,
  };
}

export function parseCurrencyInput(value: FormDataEntryValue | string | null | undefined) {
  if (typeof value !== "string") {
    return 0;
  }

  const parsed = Number(value.replace(/[^0-9.-]/g, ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

export function parseIntegerInput(value: FormDataEntryValue | string | null | undefined) {
  const parsed = Math.trunc(parseCurrencyInput(value));
  return parsed > 0 ? parsed : 0;
}

export function parseNullableCurrencyInput(
  value: FormDataEntryValue | string | null | undefined,
) {
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }
  const parsed = Number(value.replace(/[^0-9.-]/g, ""));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

export function parseNullableIntegerInput(
  value: FormDataEntryValue | string | null | undefined,
) {
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }
  const parsed = Math.trunc(Number(value.replace(/[^0-9.-]/g, "")));
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

export function parseFulfillmentMode(value: FormDataEntryValue | string | null | undefined) {
  return value === "made_to_order" || value === "stocked_with_mto" ? value : "stocked";
}

export function parseNullableText(value: FormDataEntryValue | string | null | undefined) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

export function parseRequiredText(value: FormDataEntryValue | string | null | undefined) {
  const parsed = parseNullableText(value);
  if (!parsed) {
    throw new Error("Required field is missing.");
  }
  return parsed;
}

export function parseListInput(value: FormDataEntryValue | string | null | undefined) {
  if (typeof value !== "string") {
    return [];
  }

  return value
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

export function parseJsonArrayInput(value: FormDataEntryValue | string | null | undefined) {
  if (typeof value !== "string" || value.trim().length === 0) {
    return [];
  }

  const parsed = JSON.parse(value);
  if (!Array.isArray(parsed)) {
    throw new Error("Expected a JSON array.");
  }
  return parsed;
}
