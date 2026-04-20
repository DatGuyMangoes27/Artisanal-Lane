import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import {
  createCheckoutLink,
  createTradeSafeTransaction,
  ensureTradeSafeToken,
  mapTradeSafeBank,
  mapTradeSafeBankAccountType,
  normalizeMobile,
} from "../_shared/tradesafe.ts";

const GIFT_SERVICE_FEE = 30;

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

Deno.serve(async (request) => {
  try {
    const body = await request.json();
    const shippingAddress =
      (body.shippingAddress ?? {}) as Record<string, unknown>;
    const requestUserId =
      typeof body.userId === "string" && body.userId.trim().length > 0
        ? body.userId.trim()
        : null;

    let userId = requestUserId;
    const authHeader = request.headers.get("Authorization");
    console.log(
      "[checkout-debug] create-checkout request",
      JSON.stringify({
        hasAuthHeader: authHeader?.startsWith("Bearer ") ?? false,
        requestUserId,
        shippingMethod: body.shippingMethod ?? null,
        shippingCost: body.shippingCost ?? null,
        isGift: body.isGift === true,
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
        // Fall back to the app-provided user ID when JWT verification is disabled.
      }
    }

    if (userId == null) {
      console.log("[checkout-debug] no userId available after auth fallback");
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
        "id, product_id, variant_id, quantity, products(id, title, price, shop_id), product_variants(id, color_name, display_name, option_values, price, stock_qty, images)",
      )
      .eq("cart_id", cartRow.id);

    if (cartError || !cartItems || cartItems.length === 0) {
      console.log(
        `[checkout-debug] cart items missing cartError=${cartError?.message ?? "none"} itemCount=${cartItems?.length ?? 0}`,
      );
      return jsonResponse({ error: "Your cart is empty." }, { status: 400 });
    }
    console.log(`[checkout-debug] cart item count=${cartItems.length}`);

    const items = cartItems.map((item) => ({
      id: item.id as string,
      productId: item.product_id as string,
      variantId: item.variant_id as string | null,
      quantity: item.quantity as number,
      product: item.products as {
        id: string;
        title: string;
        price: number;
        shop_id: string;
      },
      variant: item.product_variants as
        | {
            id: string;
            color_name: string;
            display_name: string | null;
            option_values: string[] | null;
            price: number;
            stock_qty: number;
            images: string[] | null;
          }
        | null,
    }));

    const shopIds = new Set(items.map((item) => item.product.shop_id));
    if (shopIds.size !== 1) {
      return jsonResponse(
        {
          error:
            "Checkout currently supports one artisan shop per order. Please complete each shop separately.",
        },
        { status: 400 },
      );
    }

    const shopId = Array.from(shopIds)[0];
    const shippingCost = Number(body.shippingCost ?? 0);
    const giftFee = body.isGift === true ? GIFT_SERVICE_FEE : 0;
    const subtotal = items.reduce(
      (sum, item) =>
        sum + Number(item.variant?.price ?? item.product.price) * item.quantity,
      0,
    );
    const grandTotal = subtotal + shippingCost + giftFee;
    console.log(
      `[checkout-debug] totals subtotal=${subtotal} shippingCost=${shippingCost} giftFee=${giftFee} grandTotal=${grandTotal}`,
    );

    for (const item of items) {
      if (item.variant && item.quantity > Number(item.variant.stock_qty ?? 0)) {
        return jsonResponse(
          {
            error: `${item.variant.display_name ?? item.variant.color_name} is low on stock. Please update your basket and try again.`,
          },
          { status: 400 },
        );
      }
    }

    const [{ data: buyerProfile }, { data: shop }] = await Promise.all([
      admin
        .from("profiles")
        .select("id, display_name, email, phone, tradesafe_token_id")
        .eq("id", userId)
        .single(),
      admin
        .from("shops")
        .select("id, name, vendor_id")
        .eq("id", shopId)
        .single(),
    ]);
    console.log(
      `[checkout-debug] buyerProfile emailPresent=${buyerProfile?.email != null} shopId=${shop?.id ?? "none"} vendorId=${shop?.vendor_id ?? "none"}`,
    );

    if (!buyerProfile?.email) {
      return jsonResponse(
        { error: "Your profile must include an email address." },
        { status: 400 },
      );
    }

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
      `[checkout-debug] sellerProfile emailPresent=${sellerProfile?.email != null} payoutPhonePresent=${typeof sellerPayoutProfile?.registered_phone === "string" && sellerPayoutProfile.registered_phone.trim().length > 0}`,
    );

    if (!sellerProfile?.email) {
      return jsonResponse(
        { error: "The seller profile is missing an email address." },
        { status: 400 },
      );
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
    const sellerSubscriptionActive =
      (sellerSubscriptionStatus === "active" &&
        (sellerSubscriptionPeriodEndDate == null || periodStillValid)) ||
      (sellerSubscriptionStatus === "cancelled" && periodStillValid);

    if (!sellerSubscriptionActive) {
      return jsonResponse(
        {
          error:
            "This artisan needs an active Artisan Lane subscription before checkout can start.",
        },
        { status: 400 },
      );
    }

    const buyerPhone = firstNonEmptyString(
      buyerProfile.phone,
      shippingAddress["phone"],
    );
    const sellerEmail = firstNonEmptyString(
      sellerProfile.email,
      sellerPayoutProfile?.registered_email,
    );
    const sellerPhone = firstNonEmptyString(
      sellerProfile.phone,
      sellerPayoutProfile?.registered_phone,
    );
    const sellerIdentityNumber = firstNonEmptyString(
      sellerPayoutProfile?.identity_number,
    );
    const sellerBusinessRegistrationNumber = firstNonEmptyString(
      sellerPayoutProfile?.business_registration_number,
    );
    const sellerBankAccountNumber = firstNonEmptyString(
      sellerPayoutProfile?.account_number,
    );
    const sellerBank = mapTradeSafeBank(
      sellerPayoutProfile?.bank_name as string | null | undefined,
    );
    const sellerBankAccountType = mapTradeSafeBankAccountType(
      sellerPayoutProfile?.account_type as string | null | undefined,
    );
    console.log(
      `[checkout-debug] buyerPhonePresent=${buyerPhone != null} sellerPhonePresent=${sellerPhone != null} sellerEmailPresent=${sellerEmail != null} sellerIdentityPresent=${sellerIdentityNumber != null} sellerBankAccountPresent=${sellerBankAccountNumber != null} sellerBankTypePresent=${sellerBankAccountType != null}`,
    );

    if (buyerPhone == null) {
      return jsonResponse(
        {
          error:
            "A phone number is required for checkout. Please enter a valid number in the delivery details.",
        },
        { status: 400 },
      );
    }

    if (sellerPhone == null) {
      return jsonResponse(
        {
          error:
            "This seller needs to add a phone number before TradeSafe checkout can start.",
        },
        { status: 400 },
      );
    }

    if (sellerEmail == null) {
      return jsonResponse(
        {
          error:
            "This seller needs a valid email address before TradeSafe checkout can start.",
        },
        { status: 400 },
      );
    }

    const buyerTokenId = await ensureTradeSafeToken({
      existingTokenId: null,
      displayName:
        (buyerProfile.display_name as string | null) ??
            (buyerProfile.email as string | null) ??
            "Buyer",
      email: buyerProfile.email as string,
      mobile: normalizeMobile(buyerPhone),
    });
    console.log(`[checkout-debug] buyerTokenId=${buyerTokenId}`);

    const sellerTokenId = await ensureTradeSafeToken({
      existingTokenId: null,
      displayName:
        (sellerProfile.display_name as string | null) ??
            (sellerPayoutProfile?.account_holder_name as string | null) ??
            (shop.name as string | null) ??
            "Seller",
      email: sellerEmail,
      mobile: normalizeMobile(sellerPhone),
      idNumber: sellerIdentityNumber,
      idType: sellerIdentityNumber != null ? "NATIONAL" : undefined,
      idCountry: sellerIdentityNumber != null ? "ZAF" : null,
      organization: sellerBusinessRegistrationNumber != null
          ? {
              name: (shop.name as string | null) ?? sellerEmail,
              tradeName: shop.name as string | null,
              type: "PRIVATE",
              registrationNumber: sellerBusinessRegistrationNumber,
            }
          : null,
      bankAccount:
        sellerBankAccountNumber != null && sellerBankAccountType != null
          ? {
              bank: sellerBank,
              accountNumber: sellerBankAccountNumber,
              accountType: sellerBankAccountType,
            }
          : null,
    });
    console.log(`[checkout-debug] sellerTokenId=${sellerTokenId}`);

    await Promise.all([
      admin
        .from("profiles")
        .update({ tradesafe_token_id: buyerTokenId })
        .eq("id", buyerProfile.id),
      admin
        .from("profiles")
        .update({ tradesafe_token_id: sellerTokenId })
        .eq("id", sellerProfile.id),
    ]);

    const { data: orderRow, error: orderError } = await admin
      .from("orders")
      .insert({
        buyer_id: userId,
        shop_id: shopId,
        status: "pending",
        total: subtotal,
        shipping_cost: shippingCost,
        shipping_method: body.shippingMethod as string | null,
        shipping_address: shippingAddress,
        is_gift: body.isGift === true,
        gift_recipient: body.giftRecipient as string | null,
        gift_message: body.giftMessage as string | null,
        payment_provider: "tradesafe",
        payment_state: "checkout_created",
      })
      .select("id")
      .single();

    if (orderError || !orderRow) {
      console.log(
        `[checkout-debug] order creation failed error=${orderError?.message ?? "unknown"}`,
      );
      throw orderError ?? new Error("Failed to create local order.");
    }
    console.log(`[checkout-debug] order created orderId=${orderRow.id}`);

    const orderId = orderRow.id as string;
    const paymentReference = `order-${orderId}`;

    const transaction = await createTradeSafeTransaction({
      reference: paymentReference,
      title: `Artisan Lane order ${orderId.substring(0, 8).toUpperCase()}`,
      description: `Marketplace order for ${shop.name as string}`,
      buyerTokenId,
      sellerTokenId,
      amount: grandTotal,
    });
    console.log(
      `[checkout-debug] tradesafe transaction created transactionId=${transaction.transactionId} allocationId=${transaction.allocationId} state=${transaction.transactionState}`,
    );

    const checkoutUrl = await createCheckoutLink(transaction.transactionId);
    console.log(`[checkout-debug] checkoutUrl=${checkoutUrl}`);

    await admin.from("order_items").insert(
      items.map((item) => ({
        order_id: orderId,
        product_id: item.productId,
        variant_id: item.variantId,
        variant_name: item.variant?.display_name ?? item.variant?.color_name ?? null,
        variant_image:
          item.variant?.images && item.variant.images.length > 0
            ? item.variant.images[0]
            : null,
        quantity: item.quantity,
        unit_price: item.variant?.price ?? item.product.price,
      })),
    );

    for (const item of items) {
      if (item.variantId) {
        await admin.rpc("decrement_variant_stock", {
          variant_id_input: item.variantId,
          qty_input: item.quantity,
        });
      } else {
        await admin.rpc("decrement_product_stock", {
          product_id_input: item.productId,
          qty_input: item.quantity,
        });
      }
    }

    await admin.from("escrow_transactions").insert({
      order_id: orderId,
      amount: grandTotal,
      platform_fee: 0,
      status: "pending",
      provider: "tradesafe",
      provider_transaction_id: transaction.transactionId,
      provider_allocation_id: transaction.allocationId,
      provider_state: transaction.transactionState,
    });

    await admin
      .from("orders")
      .update({
        payment_reference: paymentReference,
        payment_url: checkoutUrl,
        tradesafe_transaction_id: transaction.transactionId,
        tradesafe_allocation_id: transaction.allocationId,
        payment_state: transaction.transactionState,
      })
      .eq("id", orderId);

    return jsonResponse({
      orderId,
      checkoutUrl,
      transactionId: transaction.transactionId,
    });
  } catch (error) {
    console.log(
      `[checkout-debug] create-checkout fatal error ${error instanceof Error ? error.message : String(error)}`,
    );
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Checkout failed.",
      },
      { status: 500 },
    );
  }
});
