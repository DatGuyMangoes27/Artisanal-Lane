import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import {
  createCheckoutLink,
  createTradeSafeTransaction,
  ensureTradeSafeToken,
  normalizeMobile,
} from "../_shared/tradesafe.ts";

const GIFT_SERVICE_FEE = 7;

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (request) => {
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

    if (authError || !user) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const shippingAddress =
      (body.shippingAddress ?? {}) as Record<string, unknown>;

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: cartRow } = await admin
      .from("carts")
      .select("id")
      .eq("user_id", user.id)
      .maybeSingle();

    if (!cartRow) {
      return jsonResponse({ error: "Cart not found." }, { status: 400 });
    }

    const { data: cartItems, error: cartError } = await admin
      .from("cart_items")
      .select(
        "id, product_id, variant_id, quantity, products(id, title, price, shop_id), product_variants(id, color_name, display_name, option_values, price, stock_qty, images)",
      )
      .eq("cart_id", cartRow.id);

    if (cartError || !cartItems || cartItems.length === 0) {
      return jsonResponse({ error: "Your cart is empty." }, { status: 400 });
    }

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
        .eq("id", user.id)
        .single(),
      admin
        .from("shops")
        .select("id, name, vendor_id")
        .eq("id", shopId)
        .single(),
    ]);

    if (!buyerProfile?.email) {
      return jsonResponse(
        { error: "Your profile must include an email address." },
        { status: 400 },
      );
    }

    const { data: sellerProfile } = await admin
      .from("profiles")
      .select("id, display_name, email, phone, tradesafe_token_id")
      .eq("id", shop.vendor_id)
      .single();

    if (!sellerProfile?.email) {
      return jsonResponse(
        { error: "The seller profile is missing an email address." },
        { status: 400 },
      );
    }

    const buyerTokenId = await ensureTradeSafeToken({
      existingTokenId: buyerProfile.tradesafe_token_id as string | null,
      displayName:
        (buyerProfile.display_name as string | null) ?? user.email ?? "Buyer",
      email: buyerProfile.email as string,
      mobile: normalizeMobile(
        (buyerProfile.phone as string | null) ??
            (shippingAddress["phone"] as string | null),
      ),
    });

    const sellerTokenId = await ensureTradeSafeToken({
      existingTokenId: sellerProfile.tradesafe_token_id as string | null,
      displayName:
        (sellerProfile.display_name as string | null) ??
            (shop.name as string | null) ??
            "Seller",
      email: sellerProfile.email as string,
      mobile: normalizeMobile(sellerProfile.phone as string | null),
    });

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
        buyer_id: user.id,
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
      throw orderError ?? new Error("Failed to create local order.");
    }

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

    const checkoutUrl = await createCheckoutLink(transaction.transactionId);

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
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Checkout failed.",
      },
      { status: 500 },
    );
  }
});
