import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse, optionsResponse } from "../_shared/http.ts";
import { isBobGoEnabled } from "../_shared/bobgo.ts";
import { isFulfillmentProfileComplete } from "../_shared/bobgo-tracking.mjs";
import { fundCheckoutGroup, settleOpenCheckoutGroupsForBuyer } from "../_shared/checkout-groups.ts";
import {
  cancelTradeSafeTransaction,
  createCheckoutLink,
  createTradeSafeTransaction,
  createTradeSafeWalletDeposit,
  ensureTradeSafeToken,
  getTradeSafeBuyerDeposit,
  getTradeSafeTokenBalance,
  mapTradeSafeBank,
  mapTradeSafeBankAccountType,
  normalizeMobile,
} from "../_shared/tradesafe.ts";

const GIFT_SERVICE_FEE = 30;
// Matches the stale-checkout cleanup, which cancels unpaid orders after 30 minutes.
const MULTI_SHOP_PAYMENT_MINUTES = 30;

function roundCurrency(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/** A problem with the buyer's checkout (returned as a 400 with this message). */
class CheckoutRequestError extends Error {}

function firstNonEmptyString(...values: Array<unknown>) {
  for (const value of values) {
    if (typeof value != "string") continue;
    const trimmed = value.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
  }
  return null;
}

function errorMessage(error: unknown, fallback = "Checkout failed.") {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message;
  }

  if (
    typeof error === "object" && error != null && "message" in error &&
    typeof error.message === "string" && error.message.trim().length > 0
  ) {
    return error.message;
  }

  return fallback;
}

type ProductShippingOption = {
  key?: unknown;
  enabled?: unknown;
  price?: unknown;
};

type BobGoRate = {
  rateResponseId?: unknown;
  providerSlug?: unknown;
  serviceLevelCode?: unknown;
  amount?: unknown;
};

type CheckoutItem = {
  id: string;
  productId: string;
  variantId: string | null;
  quantity: number;
  isMadeToOrder: boolean;
  customNote: string | null;
  product: {
    id: string;
    title: string;
    price: number;
    shop_id: string;
    stock_qty: number;
    fulfillment_mode: string | null;
    made_to_order_price: number | null;
    made_to_order_lead_min_days: number | null;
    made_to_order_lead_max_days: number | null;
    made_to_order_capacity: number | null;
    shipping_options: unknown;
    shops: {
      combined_shipping_enabled: boolean;
    } | null;
  };
  variant: {
    id: string;
    color_name: string;
    display_name: string | null;
    option_values: string[] | null;
    price: number;
    stock_qty: number;
    images: string[] | null;
  } | null;
};

/** The buyer's delivery choice for one shop. */
type ShopSelection = {
  shopId: string;
  shippingMethod: string | null;
  clientShippingCost: number;
  bobgo: {
    quoteId: string | null;
    rateResponseId: number;
    providerSlug: string | null;
    serviceLevelCode: string | null;
  };
};

type BobGoSelection = {
  quoteId: string;
  rateRequestId: number;
  rateResponseId: number;
  providerSlug: string;
  serviceLevelCode: string;
};

type AppliedCoupon = {
  id: string;
  code: string;
  discount_type: "percentage" | "fixed";
  discount_value: number;
  scope: "store" | "products";
  minimum_subtotal: number;
  starts_at: string | null;
  ends_at: string | null;
  is_active: boolean;
};

type ShopQuote = {
  shopId: string;
  items: CheckoutItem[];
  shippingMethod: string;
  shippingCost: number;
  combinedShippingEnabled: boolean;
  bobGoSelection: BobGoSelection | null;
  giftFee: number;
  subtotal: number;
  appliedCoupon: AppliedCoupon | null;
  discountAmount: number;
  discountedSubtotal: number;
  grandTotal: number;
};

type SellerCheckoutDetails = {
  shop: { id: string; name: string; vendor_id: string };
  sellerProfileId: string;
  displayName: string;
  email: string;
  phone: string;
  identityNumber: string;
  bank: ReturnType<typeof mapTradeSafeBank>;
  bankAccountNumber: string;
  bankAccountType: NonNullable<ReturnType<typeof mapTradeSafeBankAccountType>>;
};

function normalizedText(value: unknown) {
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ").toLowerCase() : "";
}

function sameBobGoDeliveryAddress(
  requestSnapshot: unknown,
  shippingAddress: Record<string, unknown>,
) {
  if (typeof requestSnapshot !== "object" || requestSnapshot == null) return false;
  const delivery = (requestSnapshot as { delivery_address?: unknown }).delivery_address;
  if (typeof delivery !== "object" || delivery == null) return false;
  const address = delivery as Record<string, unknown>;
  return [
    [address.street_address, shippingAddress["street"]],
    // Quotes fall back to the city when no suburb was given.
    [address.local_area, firstNonEmptyString(shippingAddress["local_area"], shippingAddress["city"])],
    [address.city, shippingAddress["city"]],
    [address.zone, shippingAddress["province"]],
    [address.code, shippingAddress["postal_code"]],
  ].every(([quoted, submitted]) => normalizedText(quoted) === normalizedText(submitted));
}

function calculateShopShippingCost(
  items: Array<{
    quantity: number;
    product: { shipping_options: unknown };
  }>,
  methodKey: string,
  combinedShippingEnabled: boolean,
) {
  let total = 0;

  for (const item of items) {
    if (!Array.isArray(item.product.shipping_options)) {
      throw new Error(
        `Shipping method ${methodKey} is not available for every product.`,
      );
    }

    const option = (item.product.shipping_options as ProductShippingOption[])
      .find((candidate) =>
        candidate.key === methodKey && candidate.enabled !== false
      );
    const price = Number(option?.price);

    if (!option || !Number.isFinite(price) || price < 0) {
      throw new Error(
        `Shipping method ${methodKey} is not available for every product.`,
      );
    }

    total = combinedShippingEnabled
      ? Math.max(total, price)
      : total + price * item.quantity;
  }

  return total;
}

// Made-to-order lines use the product MTO price override when set,
// otherwise the normal variant/product price.
function unitPriceFor(item: CheckoutItem) {
  const basePrice = Number(item.variant?.price ?? item.product.price);
  if (item.isMadeToOrder && item.product.made_to_order_price != null) {
    return Number(item.product.made_to_order_price);
  }
  return basePrice;
}

function itemLabel(item: CheckoutItem) {
  return item.variant?.display_name ?? item.variant?.color_name ?? item.product.title;
}

function parseShopSelection(raw: Record<string, unknown>, shopId: string): ShopSelection {
  return {
    shopId,
    shippingMethod: firstNonEmptyString(raw.shippingMethod),
    clientShippingCost: Number(raw.shippingCost ?? 0),
    bobgo: {
      quoteId: firstNonEmptyString(raw.bobgoQuoteId),
      rateResponseId: Number(raw.bobgoRateResponseId),
      providerSlug: firstNonEmptyString(raw.bobgoProviderSlug),
      serviceLevelCode: firstNonEmptyString(raw.bobgoServiceLevelCode),
    },
  };
}

/** Prices one shop's items and verifies its delivery choice (incl. Bob Go). */
async function quoteShop(
  admin: SupabaseClient,
  userId: string,
  items: CheckoutItem[],
  selection: ShopSelection,
  shippingAddress: Record<string, unknown>,
  isGift: boolean,
): Promise<ShopQuote> {
  const shopId = selection.shopId;
  const shippingMethod = selection.shippingMethod;
  if (shippingMethod == null) {
    throw new CheckoutRequestError("Please select a shipping method.");
  }

  let shippingCost: number;
  let bobGoSelection: BobGoSelection | null = null;
  const combinedShippingEnabled =
    items[0]?.product.shops?.combined_shipping_enabled !== false;
  if (shippingMethod === "bobgo_door_to_door") {
    if (!isBobGoEnabled() || !Deno.env.get("TRADESAFE_ARTISAN_LANE_TOKEN_ID")) {
      throw new CheckoutRequestError(
        "Bob Go delivery is not available right now. Please choose another delivery option.",
      );
    }
    const { quoteId, rateResponseId, providerSlug, serviceLevelCode } = selection.bobgo;
    if (
      !quoteId || !Number.isFinite(rateResponseId) || !providerSlug || !serviceLevelCode
    ) {
      throw new CheckoutRequestError("Request and select a current Bob Go delivery rate.");
    }

    // The artisan may have switched Bob Go off since the quote.
    const { data: fulfillment } = await admin
      .from("shop_fulfillment_profiles")
      .select(
        "contact_full_name, contact_email, contact_phone, street_address, local_area, city, province, postal_code, bobgo_enabled",
      )
      .eq("shop_id", shopId)
      .maybeSingle();
    if (!isFulfillmentProfileComplete(fulfillment)) {
      throw new CheckoutRequestError(
        "This artisan no longer offers Bob Go delivery. Please choose another delivery option.",
      );
    }

    const { data: quote, error: quoteError } = await admin
      .from("bobgo_shipping_quotes")
      .select("id, rate_request_id, rates, items_snapshot, request_snapshot, expires_at")
      .eq("id", quoteId)
      .eq("buyer_id", userId)
      .eq("shop_id", shopId)
      .gt("expires_at", new Date().toISOString())
      .maybeSingle();
    if (quoteError || !quote) {
      throw new CheckoutRequestError(
        "That Bob Go quote expired or no longer matches this checkout. Request a new rate.",
      );
    }

    const currentItems = items
      .map((item) => ({ productId: item.productId, quantity: item.quantity }))
      .sort((left, right) => left.productId.localeCompare(right.productId));
    const quotedItems = (Array.isArray(quote.items_snapshot) ? quote.items_snapshot : [])
      .map((item) => {
        const record = item as Record<string, unknown>;
        return {
          productId: firstNonEmptyString(record.productId) ?? "",
          quantity: Number(record.quantity),
        };
      })
      .sort((left, right) => left.productId.localeCompare(right.productId));
    const quoteMatchesCart = quotedItems.length === currentItems.length &&
      quotedItems.every((item, index) =>
        item.productId === currentItems[index].productId &&
        item.quantity === currentItems[index].quantity
      );
    if (!quoteMatchesCart) {
      throw new CheckoutRequestError("Your basket changed after the Bob Go quote. Request a new rate.");
    }
    if (!sameBobGoDeliveryAddress(quote.request_snapshot, shippingAddress)) {
      throw new CheckoutRequestError(
        "Your delivery address changed after the Bob Go quote. Request a new rate.",
      );
    }

    const selectedRate = (Array.isArray(quote.rates) ? quote.rates : [])
      .find((rate: BobGoRate) =>
        Number(rate.rateResponseId) === rateResponseId &&
        rate.providerSlug === providerSlug &&
        rate.serviceLevelCode === serviceLevelCode
      ) as BobGoRate | undefined;
    const verifiedShippingCost = Number(selectedRate?.amount);
    if (!selectedRate || !Number.isFinite(verifiedShippingCost) || verifiedShippingCost <= 0) {
      throw new CheckoutRequestError(
        "The selected Bob Go service is no longer available. Request a new rate.",
      );
    }

    shippingCost = roundCurrency(verifiedShippingCost);
    bobGoSelection = {
      quoteId,
      rateRequestId: Number(quote.rate_request_id),
      rateResponseId,
      providerSlug,
      serviceLevelCode,
    };
  } else {
    try {
      shippingCost = calculateShopShippingCost(
        items,
        shippingMethod,
        combinedShippingEnabled,
      );
    } catch (error) {
      throw new CheckoutRequestError(
        errorMessage(error, "The selected shipping method is unavailable."),
      );
    }
  }
  if (
    Number.isFinite(selection.clientShippingCost) &&
    Math.abs(selection.clientShippingCost - shippingCost) > 0.009
  ) {
    console.log(
      `[checkout-debug] corrected client shipping cost shopId=${shopId} client=${selection.clientShippingCost} server=${shippingCost}`,
    );
  }

  const subtotal = items.reduce(
    (sum, item) => sum + unitPriceFor(item) * item.quantity,
    0,
  );
  const giftFee = isGift ? GIFT_SERVICE_FEE : 0;
  const discountedSubtotal = roundCurrency(subtotal);
  return {
    shopId,
    items,
    shippingMethod,
    shippingCost,
    combinedShippingEnabled,
    bobGoSelection,
    giftFee,
    subtotal,
    appliedCoupon: null,
    discountAmount: 0,
    discountedSubtotal,
    grandTotal: roundCurrency(discountedSubtotal + shippingCost + giftFee),
  };
}

async function findShopCoupon(admin: SupabaseClient, shopId: string, couponCode: string) {
  const { data: coupon, error: couponError } = await admin
    .from("shop_coupons")
    .select(
      "id, code, discount_type, discount_value, scope, minimum_subtotal, starts_at, ends_at, is_active",
    )
    .eq("shop_id", shopId)
    .eq("code", couponCode)
    .maybeSingle();

  if (couponError) {
    throw couponError;
  }
  return coupon && coupon.is_active === true ? coupon as unknown as AppliedCoupon : null;
}

/** Applies a shop's discount code to its quote (codes belong to one shop). */
async function applyCoupon(admin: SupabaseClient, quote: ShopQuote, coupon: AppliedCoupon) {
  const now = Date.now();
  if (coupon.starts_at && new Date(coupon.starts_at).getTime() > now) {
    throw new CheckoutRequestError("This discount code is not active yet.");
  }
  if (coupon.ends_at && new Date(coupon.ends_at).getTime() <= now) {
    throw new CheckoutRequestError("This discount code has expired.");
  }

  const minimumSubtotal = Number(coupon.minimum_subtotal ?? 0);
  if (quote.subtotal + 0.0001 < minimumSubtotal) {
    throw new CheckoutRequestError(
      `This code requires a minimum product total of R${minimumSubtotal.toFixed(2)}.`,
    );
  }

  let eligibleProductIds: Set<string> | null = null;
  if (coupon.scope === "products") {
    const { data: couponProducts, error: couponProductsError } = await admin
      .from("shop_coupon_products")
      .select("product_id")
      .eq("coupon_id", coupon.id);
    if (couponProductsError) {
      throw couponProductsError;
    }
    eligibleProductIds = new Set(
      (couponProducts ?? []).map((row) => row.product_id as string),
    );
  }

  const eligibleSubtotal = quote.items.reduce((sum, item) => {
    if (eligibleProductIds != null && !eligibleProductIds.has(item.productId)) {
      return sum;
    }
    return sum + unitPriceFor(item) * item.quantity;
  }, 0);

  if (eligibleSubtotal <= 0) {
    throw new CheckoutRequestError(
      "This discount code does not apply to the products in your basket.",
    );
  }

  const discountValue = Number(coupon.discount_value);
  const rawDiscount = coupon.discount_type === "percentage"
    ? eligibleSubtotal * discountValue / 100
    : discountValue;
  quote.discountAmount = roundCurrency(Math.min(eligibleSubtotal, rawDiscount));
  quote.appliedCoupon = coupon;
  quote.discountedSubtotal = roundCurrency(quote.subtotal - quote.discountAmount);
  quote.grandTotal = roundCurrency(quote.discountedSubtotal + quote.shippingCost + quote.giftFee);
}

/** Stock and made-to-order capacity, checked before any order is created. */
async function checkAvailability(
  admin: SupabaseClient,
  items: CheckoutItem[],
  reservationToken: string | null,
) {
  for (const item of items) {
    // Made-to-order lines are produced on demand and bypass stock checks.
    if (item.isMadeToOrder || reservationToken != null) {
      continue;
    }

    const stockQty = Number(item.variant?.stock_qty ?? item.product.stock_qty ?? 0);
    if (item.quantity > stockQty) {
      throw new CheckoutRequestError(
        `${itemLabel(item)} is low on stock. Please update your basket and try again.`,
      );
    }
  }

  // Enforce the optional made-to-order capacity cap (open, not-yet-shipped units).
  for (const item of items) {
    if (!item.isMadeToOrder || item.product.made_to_order_capacity == null) {
      continue;
    }

    const { data: openUnits } = await admin.rpc("made_to_order_open_units", {
      product_id_input: item.productId,
    });
    const open = typeof openUnits === "number" ? openUnits : 0;
    if (open + item.quantity > Number(item.product.made_to_order_capacity)) {
      throw new CheckoutRequestError(
        `${item.product.title} is fully booked for made-to-order right now. Please try again later.`,
      );
    }
  }
}

/**
 * The artisan's subscription and TradeSafe payout details. In a multi-shop
 * basket, problems name the shop so the buyer knows which one to remove.
 */
async function loadSellerForCheckout(
  admin: SupabaseClient,
  shopId: string,
  nameShopInErrors: boolean,
): Promise<SellerCheckoutDetails> {
  const { data: shop } = await admin
    .from("shops")
    .select("id, name, vendor_id")
    .eq("id", shopId)
    .single();
  if (!shop) {
    throw new CheckoutRequestError("This shop is not available.");
  }
  const fail = (message: string): never => {
    throw new CheckoutRequestError(nameShopInErrors ? `${shop.name as string}: ${message}` : message);
  };

  const [
    { data: sellerProfile },
    { data: sellerPayoutProfile },
    { data: sellerSubscription },
  ] =
    await Promise.all([
      admin
        .from("profiles")
        .select("id, display_name, email, phone, tradesafe_token_id")
        .eq("id", shop.vendor_id)
        .single(),
      admin
        .from("vendor_payout_profiles")
        .select("registered_phone, registered_email, identity_number, business_registration_number, account_holder_name, bank_name, account_number, account_type")
        .eq("vendor_id", shop.vendor_id)
        .maybeSingle(),
      admin
        .from("vendor_subscriptions")
        .select("status, current_period_end")
        .eq("vendor_id", shop.vendor_id)
        .maybeSingle(),
    ]);
  console.log(
    `[checkout-debug] shopId=${shop.id} vendorId=${shop.vendor_id} sellerProfile emailPresent=${sellerProfile?.email != null} payoutPhonePresent=${typeof sellerPayoutProfile?.registered_phone === "string" && sellerPayoutProfile.registered_phone.trim().length > 0}`,
  );

  if (!sellerProfile?.email) {
    fail("The seller profile is missing an email address.");
  }

  const sellerSubscriptionPeriodEnd = sellerSubscription?.current_period_end as
    | string
    | null
    | undefined;
  const sellerSubscriptionStatus = sellerSubscription?.status;
  const sellerSubscriptionPeriodEndDate = sellerSubscriptionPeriodEnd != null
    ? new Date(sellerSubscriptionPeriodEnd)
    : null;
  const periodStillValid = sellerSubscriptionPeriodEndDate != null &&
    sellerSubscriptionPeriodEndDate > new Date();
  // Active subscriptions unlock checkout. Cancelled subscriptions stay
  // unlocked until their paid-through current_period_end so artisans keep
  // full access during the grace window they already paid for.
  // Recurring subscriptions get 5 days past their paid-through date while
  // PayFast retries a failed card or a renewal notice arrives (mirrors
  // public.vendor_subscription_is_active).
  const withinPaymentGrace = sellerSubscriptionPeriodEndDate != null &&
    sellerSubscriptionPeriodEndDate.getTime() + 5 * 24 * 60 * 60 * 1000 >
      Date.now();
  const sellerSubscriptionActive =
    ((sellerSubscriptionStatus === "active" ||
      sellerSubscriptionStatus === "past_due") &&
      (sellerSubscriptionPeriodEndDate == null || withinPaymentGrace)) ||
    (sellerSubscriptionStatus === "cancelled" && periodStillValid);

  if (!sellerSubscriptionActive) {
    fail("This artisan needs an active Artisan Lane subscription before checkout can start.");
  }

  const sellerEmail = firstNonEmptyString(
    sellerProfile!.email,
    sellerPayoutProfile?.registered_email,
  );
  const sellerPhone = firstNonEmptyString(
    sellerProfile!.phone,
    sellerPayoutProfile?.registered_phone,
  );
  const sellerIdentityNumber = firstNonEmptyString(
    sellerPayoutProfile?.identity_number,
  );
  const sellerBankName = firstNonEmptyString(
    sellerPayoutProfile?.bank_name,
  );
  const sellerBankAccountNumber = firstNonEmptyString(
    sellerPayoutProfile?.account_number,
  );
  const sellerBankAccountType = mapTradeSafeBankAccountType(
    sellerPayoutProfile?.account_type as string | null | undefined,
  );
  console.log(
    `[checkout-debug] shopId=${shop.id} sellerPhonePresent=${sellerPhone != null} sellerEmailPresent=${sellerEmail != null} sellerIdentityPresent=${sellerIdentityNumber != null} sellerBankNamePresent=${sellerBankName != null} sellerBankAccountPresent=${sellerBankAccountNumber != null} sellerBankTypePresent=${sellerBankAccountType != null}`,
  );

  if (sellerPhone == null) {
    fail("This seller needs to add a phone number before TradeSafe checkout can start.");
  }
  if (sellerEmail == null) {
    fail("This seller needs a valid email address before TradeSafe checkout can start.");
  }
  if (sellerIdentityNumber == null) {
    fail("This seller needs an ID number before TradeSafe checkout can start.");
  }
  if (
    sellerBankName == null || sellerBankAccountNumber == null ||
    sellerBankAccountType == null
  ) {
    fail("This seller needs complete bank details before TradeSafe checkout can start.");
  }

  return {
    shop: shop as SellerCheckoutDetails["shop"],
    sellerProfileId: sellerProfile!.id as string,
    displayName: (sellerProfile!.display_name as string | null) ??
      (sellerPayoutProfile?.account_holder_name as string | null) ??
      (shop.name as string | null) ??
      "Seller",
    email: sellerEmail!,
    phone: sellerPhone!,
    identityNumber: sellerIdentityNumber!,
    bank: mapTradeSafeBank(sellerBankName),
    bankAccountNumber: sellerBankAccountNumber!,
    bankAccountType: sellerBankAccountType!,
  };
}

async function ensureSellerToken(admin: SupabaseClient, seller: SellerCheckoutDetails) {
  const sellerTokenId = await ensureTradeSafeToken({
    // TradeSafe bank details are immutable once attached to a token, so use
    // the current payout profile when creating the seller token for checkout.
    existingTokenId: null,
    displayName: seller.displayName,
    email: seller.email,
    mobile: normalizeMobile(seller.phone),
    idNumber: seller.identityNumber,
    idType: "NATIONAL",
    idCountry: "ZAF",
    organization: null,
    bankAccount: {
      bank: seller.bank,
      accountNumber: seller.bankAccountNumber,
      accountType: seller.bankAccountType,
    },
    payoutSettings: {
      interval: "IMMEDIATE",
      refund: "IMMEDIATE",
    },
  });
  console.log(`[checkout-debug] shopId=${seller.shop.id} sellerTokenId=${sellerTokenId}`);
  await admin
    .from("profiles")
    .update({ tradesafe_token_id: sellerTokenId })
    .eq("id", seller.sellerProfileId);
  return sellerTokenId;
}

/**
 * Creates the local order for one shop with its items, and takes the stock
 * (or consumes the website's stock holds). Rolls the order back on failure.
 */
async function placeShopOrder(
  admin: SupabaseClient,
  input: {
    userId: string;
    quote: ShopQuote;
    shippingAddress: Record<string, unknown>;
    isGift: boolean;
    giftRecipient: string | null;
    giftMessage: string | null;
    reservationToken: string | null;
    checkoutGroupId?: string;
  },
) {
  const { quote } = input;
  const { data: orderRow, error: orderError } = await admin
    .from("orders")
    .insert({
      buyer_id: input.userId,
      shop_id: quote.shopId,
      status: "pending",
      total: quote.discountedSubtotal,
      subtotal_before_discount: quote.subtotal,
      discount_amount: quote.discountAmount,
      coupon_id: quote.appliedCoupon?.id ?? null,
      coupon_code: quote.appliedCoupon?.code ?? null,
      shipping_cost: quote.shippingCost,
      shipping_method: quote.shippingMethod,
      shipping_address: input.shippingAddress,
      is_gift: input.isGift,
      gift_recipient: input.giftRecipient,
      gift_message: input.giftMessage,
      payment_provider: "tradesafe",
      payment_state: "checkout_created",
      bobgo_quote_id: quote.bobGoSelection?.quoteId ?? null,
      bobgo_rate_request_id: quote.bobGoSelection?.rateRequestId ?? null,
      bobgo_rate_response_id: quote.bobGoSelection?.rateResponseId ?? null,
      bobgo_provider_slug: quote.bobGoSelection?.providerSlug ?? null,
      bobgo_service_level_code: quote.bobGoSelection?.serviceLevelCode ?? null,
      tradesafe_shipping_fee: quote.bobGoSelection ? quote.shippingCost : 0,
      ...(input.checkoutGroupId ? { checkout_group_id: input.checkoutGroupId } : {}),
    })
    .select("id")
    .single();

  if (orderError || !orderRow) {
    console.log(
      `[checkout-debug] order creation failed error=${orderError?.message ?? "unknown"}`,
    );
    throw orderError ?? new Error("Failed to create local order.");
  }
  console.log(`[checkout-debug] order created orderId=${orderRow.id} shopId=${quote.shopId}`);

  const orderId = orderRow.id as string;
  const items = quote.items;

  try {
    const { error: orderItemsError } = await admin.from("order_items").insert(
      items.map((item) => ({
        order_id: orderId,
        product_id: item.productId,
        variant_id: item.variantId,
        variant_name: item.variant?.display_name ?? item.variant?.color_name ??
          null,
        variant_image:
          item.variant?.images && item.variant.images.length > 0
            ? item.variant.images[0]
            : null,
        quantity: item.quantity,
        unit_price: unitPriceFor(item),
        is_made_to_order: item.isMadeToOrder,
        custom_note: item.isMadeToOrder ? item.customNote : null,
        lead_time_min_days: item.isMadeToOrder
          ? item.product.made_to_order_lead_min_days
          : null,
        lead_time_max_days: item.isMadeToOrder
          ? item.product.made_to_order_lead_max_days
          : null,
      })),
    );

    if (orderItemsError) {
      throw orderItemsError;
    }

    const hasReservableItems = items.some((item) => !item.isMadeToOrder);
    if (input.reservationToken != null && hasReservableItems) {
      const { error: consumeReservationError } = await admin.rpc(
        "consume_product_reservations",
        {
          reservation_token_input: input.reservationToken,
          order_id_input: orderId,
        },
      );

      if (consumeReservationError) {
        throw consumeReservationError;
      }
    } else if (input.reservationToken == null) {
      for (const item of items) {
        // Made-to-order lines never decrement stock.
        if (item.isMadeToOrder) {
          continue;
        }

        const { error: decrementError } = item.variantId
          ? await admin.rpc("decrement_variant_stock", {
            variant_id_input: item.variantId,
            qty_input: item.quantity,
          })
          : await admin.rpc("decrement_product_stock", {
            product_id_input: item.productId,
            qty_input: item.quantity,
          });

        if (decrementError) {
          // The unit was claimed by a concurrent checkout between the
          // availability check above and this atomic decrement. Roll back the
          // half-created order (order_items cascade) so the stale-checkout
          // cleanup can never "restore" stock that was never taken, and so we
          // never oversell or leave the item showing as in stock after a sale.
          console.log(
            `[checkout-debug] stock decrement failed orderId=${orderId} productId=${item.productId} variantId=${item.variantId ?? "none"} error=${decrementError.message}`,
          );
          await admin.from("orders").delete().eq("id", orderId);
          throw new CheckoutRequestError(
            `${itemLabel(item)} is low on stock. Please update your basket and try again.`,
          );
        }
      }
    }
  } catch (error) {
    if (error instanceof CheckoutRequestError) {
      throw error;
    }
    const failureMessage = errorMessage(error);
    const { error: rollbackError } = await admin
      .from("orders")
      .delete()
      .eq("id", orderId);
    console.log(
      `[checkout-debug] checkout setup rollback orderId=${orderId} cause=${failureMessage} rollbackError=${rollbackError?.message ?? "none"}`,
    );
    throw new Error(failureMessage);
  }

  return orderId;
}

/** One TradeSafe transaction for one shop's order (buyer + that artisan). */
async function createShopTransaction(input: {
  orderId: string;
  shopName: string;
  quote: ShopQuote;
  buyerTokenId: string;
  sellerTokenId: string;
}) {
  const { orderId, quote } = input;
  const paymentReference = `order-${orderId}`;
  const transaction = await createTradeSafeTransaction({
    reference: paymentReference,
    title: `Artisan Lane order ${orderId.substring(0, 8).toUpperCase()}`,
    description: `Marketplace order for ${input.shopName}`,
    buyerTokenId: input.buyerTokenId,
    sellerTokenId: input.sellerTokenId,
    amount: quote.grandTotal,
    platformTokenId: quote.bobGoSelection
      ? Deno.env.get("TRADESAFE_ARTISAN_LANE_TOKEN_ID") ?? null
      : null,
    platformShippingFee: quote.bobGoSelection ? quote.shippingCost : 0,
  });
  console.log(
    `[checkout-debug] tradesafe transaction created orderId=${orderId} transactionId=${transaction.transactionId} allocationId=${transaction.allocationId} state=${transaction.transactionState}`,
  );
  return { transaction, paymentReference };
}

async function recordShopTransaction(
  admin: SupabaseClient,
  input: {
    orderId: string;
    quote: ShopQuote;
    paymentReference: string;
    paymentUrl: string | null;
    transaction: Awaited<ReturnType<typeof createTradeSafeTransaction>>;
    buyerDeposit?: number | null;
    strict?: boolean;
  },
) {
  const { transaction } = input;
  const { error: escrowError } = await admin.from("escrow_transactions").insert({
    order_id: input.orderId,
    amount: input.quote.grandTotal,
    platform_fee: 0,
    status: "pending",
    provider: "tradesafe",
    provider_transaction_id: transaction.transactionId,
    provider_allocation_id: transaction.allocationId,
    provider_state: transaction.transactionState,
  });

  const { error: orderUpdateError } = await admin
    .from("orders")
    .update({
      payment_reference: input.paymentReference,
      payment_url: input.paymentUrl,
      tradesafe_transaction_id: transaction.transactionId,
      tradesafe_allocation_id: transaction.allocationId,
      tradesafe_shipping_party_id: transaction.shippingPartyId,
      payment_state: transaction.transactionState,
      ...(input.buyerDeposit !== undefined ? { tradesafe_buyer_deposit: input.buyerDeposit } : {}),
    })
    .eq("id", input.orderId);
  // The single-shop flow has always carried on past these; a basket must not,
  // or a shop's order could be left out of funding.
  if (input.strict && (escrowError || orderUpdateError)) {
    throw escrowError ?? orderUpdateError;
  }
}

Deno.serve(async (request) => {
  try {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }

    const body = await request.json();
    const shippingAddress =
      (body.shippingAddress ?? {}) as Record<string, unknown>;
    const reservationToken = firstNonEmptyString(body.reservationToken);
    const requestUserId =
      typeof body.userId === "string" && body.userId.trim().length > 0
        ? body.userId.trim()
        : null;
    const couponCode = firstNonEmptyString(body.couponCode)?.toUpperCase() ?? null;
    const previewOnly = body.previewOnly === true;
    const isGift = body.isGift === true;
    const requestedShops = Array.isArray(body.shops)
      ? (body.shops as unknown[]).filter((entry): entry is Record<string, unknown> =>
        typeof entry === "object" && entry != null
      )
      : null;

    // Only a verified sign-in identifies the buyer; a userId in the body is
    // logged for diagnostics but never trusted.
    let userId: string | null = null;
    const authHeader = request.headers.get("Authorization");
    console.log(
      "[checkout-debug] create-checkout request",
      JSON.stringify({
        hasAuthHeader: authHeader?.startsWith("Bearer ") ?? false,
        requestUserId,
        shippingMethod: body.shippingMethod ?? null,
        shippingCost: body.shippingCost ?? null,
        shopSelections: requestedShops?.length ?? null,
        isGift,
        hasReservationToken: reservationToken != null,
        hasCouponCode: couponCode != null,
        previewOnly,
        shippingAddressKeys: Object.keys(shippingAddress),
      }),
    );

    if (authHeader?.startsWith("Bearer ")) {
      try {
        const jwt = getBearerToken(request);
        const client = createClient(supabaseUrl, supabaseAnonKey, {
          global: {
            headers: {
              Authorization: `Bearer ${jwt}`,
            },
          },
          auth: {
            persistSession: false,
            autoRefreshToken: false,
          },
        });

        const {
          data: { user },
          error: authError,
        } = await client.auth.getUser();

        if (!authError && user?.id != null) {
          userId = user.id;
          console.log(
            `[checkout-debug] auth header resolved Supabase user ${user.id}`,
          );
        } else {
          console.log(
            `[checkout-debug] auth header did not resolve user authError=${authError?.message ?? "none"}`,
          );
        }
      } catch (error) {
        console.log(
          `[checkout-debug] auth header verification threw ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }

    if (userId == null) {
      console.log("[checkout-debug] no verified user for this checkout");
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }
    console.log(`[checkout-debug] proceeding with userId=${userId}`);

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: cartRow } = await admin
      .from("carts")
      .select("id")
      .eq("user_id", userId)
      .maybeSingle();

    if (!cartRow) {
      console.log(`[checkout-debug] cart not found for userId=${userId}`);
      return jsonResponse({ error: "Cart not found." }, { status: 400 });
    }
    console.log(`[checkout-debug] cart found cartId=${cartRow.id}`);

    const { data: cartItems, error: cartError } = await admin
      .from("cart_items")
      .select(
        "id, product_id, variant_id, quantity, is_made_to_order, custom_note, products(id, title, price, shop_id, stock_qty, fulfillment_mode, made_to_order_price, made_to_order_lead_min_days, made_to_order_lead_max_days, made_to_order_capacity, shipping_options, shops(combined_shipping_enabled)), product_variants(id, color_name, display_name, option_values, price, stock_qty, images)",
      )
      .eq("cart_id", cartRow.id);

    if (cartError || !cartItems || cartItems.length === 0) {
      console.log(
        `[checkout-debug] cart items missing cartError=${cartError?.message ?? "none"} itemCount=${cartItems?.length ?? 0}`,
      );
      return jsonResponse({ error: "Your cart is empty." }, { status: 400 });
    }
    console.log(`[checkout-debug] cart item count=${cartItems.length}`);

    const items: CheckoutItem[] = cartItems.map((item) => ({
      id: item.id as string,
      productId: item.product_id as string,
      variantId: item.variant_id as string | null,
      quantity: item.quantity as number,
      isMadeToOrder: item.is_made_to_order === true,
      customNote: (item.custom_note as string | null) ?? null,
      product: item.products as unknown as CheckoutItem["product"],
      variant: item.product_variants as unknown as CheckoutItem["variant"],
    }));

    // Basket shops in first-added order.
    const shopIds = Array.from(new Set(items.map((item) => item.product.shop_id)));

    if (shopIds.length > 1) {
      if (requestedShops == null) {
        // Older apps send one delivery choice for the whole basket.
        return jsonResponse(
          {
            error:
              "To check out several shops at once, please update the app. Or complete each shop separately.",
          },
          { status: 400 },
        );
      }
      return await multiShopCheckout(admin, {
        userId,
        items,
        shopIds,
        requestedShops,
        shippingAddress,
        reservationToken,
        couponCode,
        previewOnly,
        isGift,
        giftRecipient: body.giftRecipient as string | null,
        giftMessage: body.giftMessage as string | null,
      });
    }

    // Single shop: exactly the original flow. Newer clients send their
    // delivery choice in shops[]; older ones send it at the top level.
    const shopId = shopIds[0];
    const selection = parseShopSelection(
      requestedShops?.find((entry) => entry.shopId === shopId) ?? body,
      shopId,
    );
    const quote = await quoteShop(admin, userId, items, selection, shippingAddress, isGift);

    if (couponCode != null) {
      const coupon = await findShopCoupon(admin, shopId, couponCode);
      if (!coupon) {
        throw new CheckoutRequestError("This discount code is not valid for this shop.");
      }
      await applyCoupon(admin, quote, coupon);
    }

    const { subtotal, discountAmount, discountedSubtotal, shippingCost, giftFee, grandTotal, appliedCoupon } = quote;
    console.log(
      `[checkout-debug] totals subtotal=${subtotal} discount=${discountAmount} coupon=${appliedCoupon?.code ?? "none"} shippingCost=${shippingCost} combinedShippingEnabled=${quote.combinedShippingEnabled} giftFee=${giftFee} grandTotal=${grandTotal}`,
    );

    if (previewOnly) {
      return jsonResponse({
        preview: true,
        couponCode: appliedCoupon?.code ?? null,
        subtotal,
        discountAmount,
        discountedSubtotal,
        shippingCost,
        giftFee,
        total: grandTotal,
      });
    }

    await checkAvailability(admin, items, reservationToken);

    const { data: buyerProfile } = await admin
      .from("profiles")
      .select("id, display_name, email, phone, tradesafe_token_id")
      .eq("id", userId)
      .single();
    console.log(
      `[checkout-debug] buyerProfile emailPresent=${buyerProfile?.email != null}`,
    );

    const { data: shopExists } = await admin.from("shops").select("id").eq("id", shopId).maybeSingle();
    if (!shopExists) {
      return jsonResponse({ error: "This shop is not available." }, { status: 400 });
    }

    if (!buyerProfile?.email) {
      return jsonResponse(
        { error: "Your profile must include an email address." },
        { status: 400 },
      );
    }

    const seller = await loadSellerForCheckout(admin, shopId, false);
    const buyerTokenId = await ensureBuyerToken(admin, buyerProfile, shippingAddress);
    const sellerTokenId = await ensureSellerToken(admin, seller);

    const orderId = await placeShopOrder(admin, {
      userId,
      quote,
      shippingAddress,
      isGift,
      giftRecipient: body.giftRecipient as string | null,
      giftMessage: body.giftMessage as string | null,
      reservationToken,
    });

    const { transaction, paymentReference } = await createShopTransaction({
      orderId,
      shopName: seller.shop.name,
      quote,
      buyerTokenId,
      sellerTokenId,
    });

    const checkoutUrl = await createCheckoutLink(transaction.transactionId);
    console.log(`[checkout-debug] checkoutUrl=${checkoutUrl}`);

    await recordShopTransaction(admin, {
      orderId,
      quote,
      paymentReference,
      paymentUrl: checkoutUrl,
      transaction,
    });

    return jsonResponse({
      orderId,
      checkoutUrl,
      transactionId: transaction.transactionId,
      couponCode: appliedCoupon?.code ?? null,
      discountAmount,
      subtotalBeforeDiscount: subtotal,
      discountedSubtotal,
    });
  } catch (error) {
    if (error instanceof CheckoutRequestError) {
      return jsonResponse({ error: error.message }, { status: 400 });
    }
    const failureMessage = errorMessage(error);
    console.log(
      `[checkout-debug] create-checkout fatal error ${failureMessage}`,
    );
    return jsonResponse(
      {
        error: failureMessage,
      },
      { status: 500 },
    );
  }
});

async function ensureBuyerToken(
  admin: SupabaseClient,
  buyerProfile: Record<string, unknown>,
  shippingAddress: Record<string, unknown>,
) {
  const buyerPhone = firstNonEmptyString(
    buyerProfile.phone,
    shippingAddress["phone"],
  );
  console.log(`[checkout-debug] buyerPhonePresent=${buyerPhone != null}`);
  if (buyerPhone == null) {
    throw new CheckoutRequestError(
      "A phone number is required for checkout. Please enter a valid number in the delivery details.",
    );
  }

  const buyerTokenId = await ensureTradeSafeToken({
    existingTokenId: buyerProfile.tradesafe_token_id as string | null,
    displayName:
      (buyerProfile.display_name as string | null) ??
          (buyerProfile.email as string | null) ??
          "Buyer",
    email: buyerProfile.email as string,
    mobile: normalizeMobile(buyerPhone),
  });
  console.log(`[checkout-debug] buyerTokenId=${buyerTokenId}`);
  await admin
    .from("profiles")
    .update({ tradesafe_token_id: buyerTokenId })
    .eq("id", buyerProfile.id as string);
  return buyerTokenId;
}

/**
 * Several shops in one checkout: one order and one TradeSafe transaction per
 * shop (each artisan paid on their own delivery, refunds per shop), and one
 * payment for the buyer. The buyer pays the basket total into their own
 * TradeSafe wallet; checkout-groups funds each shop's transaction from it.
 */
async function multiShopCheckout(
  admin: SupabaseClient,
  input: {
    userId: string;
    items: CheckoutItem[];
    shopIds: string[];
    requestedShops: Record<string, unknown>[];
    shippingAddress: Record<string, unknown>;
    reservationToken: string | null;
    couponCode: string | null;
    previewOnly: boolean;
    isGift: boolean;
    giftRecipient: string | null;
    giftMessage: string | null;
  },
) {
  const { userId, items, shopIds, shippingAddress, reservationToken, couponCode, isGift } = input;

  const { data: shopRows } = await admin.from("shops").select("id, name").in("id", shopIds);
  const shopNames = new Map((shopRows ?? []).map((shop) => [shop.id as string, shop.name as string]));

  const quotes: ShopQuote[] = [];
  // Each shop may have its own pickup point (locker, Pargo, market) layered
  // over the buyer's delivery details; door delivery uses those as they are.
  const shopAddresses = new Map<string, Record<string, unknown>>();
  for (const shopId of shopIds) {
    const shopName = shopNames.get(shopId);
    if (!shopName) {
      throw new CheckoutRequestError("A shop in your basket is no longer available.");
    }
    const requested = input.requestedShops.find((entry) => entry.shopId === shopId);
    if (!requested || firstNonEmptyString(requested.shippingMethod) == null) {
      throw new CheckoutRequestError(`Please choose a delivery option for ${shopName}.`);
    }
    const override = requested.shippingAddress;
    const shopAddress = typeof override === "object" && override != null && !Array.isArray(override)
      ? { ...shippingAddress, ...(override as Record<string, unknown>) }
      : shippingAddress;
    shopAddresses.set(shopId, shopAddress);
    try {
      quotes.push(
        await quoteShop(
          admin,
          userId,
          items.filter((item) => item.product.shop_id === shopId),
          parseShopSelection(requested, shopId),
          shopAddress,
          isGift,
        ),
      );
    } catch (error) {
      if (error instanceof CheckoutRequestError) {
        throw new CheckoutRequestError(`${shopName}: ${error.message}`);
      }
      throw error;
    }
  }

  // Discount codes belong to one shop; apply the code to the shop that has it.
  if (couponCode != null) {
    let applied = false;
    for (const quote of quotes) {
      const coupon = await findShopCoupon(admin, quote.shopId, couponCode);
      if (coupon) {
        await applyCoupon(admin, quote, coupon);
        applied = true;
        break;
      }
    }
    if (!applied) {
      throw new CheckoutRequestError("This discount code is not valid for the shops in your basket.");
    }
  }

  const sum = (pick: (quote: ShopQuote) => number) =>
    roundCurrency(quotes.reduce((total, quote) => total + pick(quote), 0));
  const totals = {
    subtotal: sum((quote) => quote.subtotal),
    discountAmount: sum((quote) => quote.discountAmount),
    discountedSubtotal: sum((quote) => quote.discountedSubtotal),
    shippingCost: sum((quote) => quote.shippingCost),
    giftFee: sum((quote) => quote.giftFee),
    total: sum((quote) => quote.grandTotal),
  };
  const appliedCode = quotes.find((quote) => quote.appliedCoupon)?.appliedCoupon?.code ?? null;
  const shopBreakdown = quotes.map((quote) => ({
    shopId: quote.shopId,
    shopName: shopNames.get(quote.shopId),
    subtotal: quote.subtotal,
    discountAmount: quote.discountAmount,
    shippingCost: quote.shippingCost,
    giftFee: quote.giftFee,
    total: quote.grandTotal,
  }));
  console.log(
    `[checkout-debug] multi-shop totals shops=${quotes.length} subtotal=${totals.subtotal} discount=${totals.discountAmount} coupon=${appliedCode ?? "none"} shipping=${totals.shippingCost} giftFee=${totals.giftFee} total=${totals.total}`,
  );

  if (input.previewOnly) {
    return jsonResponse({ preview: true, couponCode: appliedCode, ...totals, shops: shopBreakdown });
  }

  await checkAvailability(admin, items, reservationToken);

  const { data: buyerProfile } = await admin
    .from("profiles")
    .select("id, display_name, email, phone, tradesafe_token_id")
    .eq("id", userId)
    .single();
  if (!buyerProfile?.email) {
    throw new CheckoutRequestError("Your profile must include an email address.");
  }

  // Every artisan must be able to take payment before anything is created.
  const sellers = new Map<string, SellerCheckoutDetails>();
  for (const quote of quotes) {
    sellers.set(quote.shopId, await loadSellerForCheckout(admin, quote.shopId, true));
  }

  const push = { supabaseUrl, serviceRoleKey: supabaseServiceRoleKey };
  // An older unpaid basket of this buyer's is settled first, so two baskets
  // never draw on the same TradeSafe wallet money.
  const settled = await settleOpenCheckoutGroupsForBuyer(admin, userId, push);
  if (settled.funded.length > 0) {
    throw new CheckoutRequestError(
      "Your earlier payment has just come through and those orders are placed. Check your orders before buying again.",
    );
  }
  if (settled.unsettled.length > 0) {
    throw new CheckoutRequestError(
      "Your previous checkout is still being processed. Please try again in a minute.",
    );
  }

  const buyerTokenId = await ensureBuyerToken(admin, buyerProfile, shippingAddress);
  const sellerTokens = new Map<string, string>();
  for (const [shopId, seller] of sellers) {
    sellerTokens.set(shopId, await ensureSellerToken(admin, seller));
  }

  // The basket exists from the start (status "building", which is never
  // funded) and every order is linked to it as it is created, so a failure at
  // any point can be undone completely.
  const { data: group, error: groupError } = await admin
    .from("checkout_groups")
    .insert({ buyer_id: userId, buyer_token_id: buyerTokenId, status: "building" })
    .select("id")
    .single();
  if (groupError || !group) {
    throw groupError ?? new Error("Could not start this checkout.");
  }
  const checkoutGroupId = group.id as string;

  const created: string[] = [];
  let depositUrl: string | null = null;
  let totalDue = 0;
  try {
    const placed: Array<{ orderId: string; quote: ShopQuote }> = [];
    for (const quote of quotes) {
      const orderId = await placeShopOrder(admin, {
        userId,
        quote,
        shippingAddress: shopAddresses.get(quote.shopId) ?? shippingAddress,
        isGift,
        giftRecipient: input.giftRecipient,
        giftMessage: input.giftMessage,
        reservationToken,
        checkoutGroupId,
      });
      created.push(orderId);
      placed.push({ orderId, quote });
    }

    for (const entry of placed) {
      const { transaction, paymentReference } = await createShopTransaction({
        orderId: entry.orderId,
        shopName: sellers.get(entry.quote.shopId)!.shop.name,
        quote: entry.quote,
        buyerTokenId,
        sellerTokenId: sellerTokens.get(entry.quote.shopId)!,
      });
      // Recorded straight away so a later failure can cancel this transaction.
      await recordShopTransaction(admin, {
        orderId: entry.orderId,
        quote: entry.quote,
        paymentReference,
        paymentUrl: null,
        transaction,
        strict: true,
      });
      const buyerDeposit = await getTradeSafeBuyerDeposit(transaction.transactionId);
      const { error: depositError } = await admin
        .from("orders")
        .update({ tradesafe_buyer_deposit: buyerDeposit })
        .eq("id", entry.orderId);
      if (depositError) throw depositError;
      totalDue = roundCurrency(totalDue + buyerDeposit);
    }

    // Money already in the buyer's TradeSafe wallet (e.g. change from an
    // earlier basket) counts towards this one.
    const walletBalance = await getTradeSafeTokenBalance(buyerTokenId);
    const depositAmount = Math.max(0, Math.ceil(totalDue - walletBalance - 0.0001));
    const deposit = depositAmount > 0
      ? await createTradeSafeWalletDeposit({
        tokenId: buyerTokenId,
        amount: depositAmount,
        minutes: MULTI_SHOP_PAYMENT_MINUTES,
      })
      : null;
    depositUrl = deposit?.url ?? null;
    console.log(
      `[checkout-debug] multi-shop payment group=${checkoutGroupId} totalDue=${totalDue} walletBalance=${walletBalance} deposit=${depositAmount}`,
    );

    if (depositUrl) {
      const { error: linkError } = await admin.from("orders").update({ payment_url: depositUrl }).in("id", created);
      if (linkError) throw linkError;
    }
    const { error: readyError } = await admin
      .from("checkout_groups")
      .update({
        status: "awaiting_payment",
        total_due: totalDue,
        deposit_amount: depositAmount,
        deposit_intent_id: deposit?.id ?? null,
        deposit_url: depositUrl,
        deposit_expires_at: new Date(Date.now() + MULTI_SHOP_PAYMENT_MINUTES * 60 * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", checkoutGroupId)
      .eq("status", "building");
    if (readyError) throw readyError;
  } catch (error) {
    // Undo the whole basket: cancel the unpaid orders (returning their stock)
    // and only the TradeSafe transactions of the orders actually cancelled.
    // Nothing in a "building" basket has been paid.
    const { data: cancelled, error: cancelError } = created.length > 0
      ? await admin.rpc("cancel_unpaid_checkout_orders", { order_ids: created })
      : { data: [], error: null };
    console.log(
      `[checkout-debug] multi-shop rollback group=${checkoutGroupId} orders=${created.join(",")} cancelError=${cancelError?.message ?? "none"}`,
    );
    for (const row of (cancelled ?? []) as Array<{ tradesafe_transaction_id: string | null }>) {
      if (!row.tradesafe_transaction_id) continue;
      await cancelTradeSafeTransaction(row.tradesafe_transaction_id, "Checkout could not be completed.")
        .catch((rollbackError) =>
          console.log(
            `[checkout-debug] rollback cancel failed transactionId=${row.tradesafe_transaction_id} ${errorMessage(rollbackError)}`,
          )
        );
    }
    await admin
      .from("checkout_groups")
      .update({ status: "cancelled", last_error: errorMessage(error).slice(0, 500), updated_at: new Date().toISOString() })
      .eq("id", checkoutGroupId)
      .eq("status", "building");
    throw error;
  }

  // Ready. If the buyer's wallet already covers it, fund the shops now.
  const status = depositUrl == null
    ? (await fundCheckoutGroup(admin, checkoutGroupId, push)).status
    : "awaiting_payment";

  return jsonResponse({
    checkoutGroupId,
    status,
    orderId: created[0],
    orderIds: created,
    checkoutUrl: depositUrl,
    couponCode: appliedCode,
    discountAmount: totals.discountAmount,
    subtotalBeforeDiscount: totals.subtotal,
    discountedSubtotal: totals.discountedSubtotal,
    total: totalDue,
    shops: shopBreakdown,
  });
}
