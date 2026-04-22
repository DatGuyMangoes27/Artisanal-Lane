import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { buildPayFastOnceOffCheckoutUrl } from "../_shared/payfast.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const stationeryReturnUrl =
  "https://artisanlanesa.co.za/vendor/stationery/success";
const stationeryCancelUrl =
  "https://artisanlanesa.co.za/vendor/stationery/error";

const stationeryCatalog = {
  gift_tag: { name: "Gift Tag", unitPrice: 7 },
  wrap_sheet: { name: "Wrap Sheet", unitPrice: 15 },
  sticker: { name: "Sticker", unitPrice: 4 },
} as const;

type StationeryCatalogKey = keyof typeof stationeryCatalog;

type StationeryItemInput = {
  key?: string;
  name?: string;
  quantity?: number;
};

type StationeryRequestRow = {
  id: string;
  shop_id: string;
  vendor_id: string;
  items: StationeryItemInput[] | null;
  delivery_address: string | null;
  notes: string | null;
  status: string;
  amount: number | string | null;
};

function firstNonEmptyString(...values: Array<unknown>) {
  for (const value of values) {
    if (typeof value !== "string") continue;
    const trimmed = value.trim();
    if (trimmed.length > 0) {
      return trimmed;
    }
  }
  return null;
}

function normalizeItems(items: unknown) {
  if (!Array.isArray(items)) return [];

  return items
    .map((item) => {
      const raw = item as StationeryItemInput;
      const key = (raw.key ?? "").trim() as StationeryCatalogKey;
      const catalogEntry = stationeryCatalog[key];
      const quantity = Number(raw.quantity ?? 0);
      if (!catalogEntry || !Number.isFinite(quantity) || quantity <= 0) {
        return null;
      }

      return {
        key,
        name: catalogEntry.name,
        quantity: Math.floor(quantity),
        unitPrice: catalogEntry.unitPrice,
      };
    })
    .filter((item): item is NonNullable<typeof item> => item != null);
}

function calculateAmount(items: ReturnType<typeof normalizeItems>) {
  return items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);
}

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

    if (authError != null || user?.id == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const body =
      request.method === "POST"
        ? ((await request.json()) as Record<string, unknown>)
        : {};

    const requestId = typeof body.requestId === "string"
      ? body.requestId.trim()
      : "";

    const [{ data: profile }, { data: shop }] = await Promise.all([
      admin
        .from("profiles")
        .select("id, role, display_name, email")
        .eq("id", user.id)
        .single(),
      admin
        .from("shops")
        .select("id, name")
        .eq("vendor_id", user.id)
        .maybeSingle(),
    ]);

    if (profile?.role !== "vendor") {
      return jsonResponse(
        { error: "Only approved artisans can order stationery." },
        { status: 403 },
      );
    }

    if (shop == null) {
      return jsonResponse(
        { error: "Finish your artisan onboarding before ordering stationery." },
        { status: 400 },
      );
    }

    let stationeryRequest: StationeryRequestRow | null = null;
    let normalizedItems: ReturnType<typeof normalizeItems> = [];
    let amount = 0;
    let deliveryAddress: string | null = null;
    let notes: string | null = null;

    if (requestId) {
      const { data: existingRequest } = await admin
        .from("stationery_requests")
        .select(
          "id, shop_id, vendor_id, items, delivery_address, notes, status, amount",
        )
        .eq("id", requestId)
        .eq("vendor_id", user.id)
        .maybeSingle();

      if (existingRequest == null) {
        return jsonResponse(
          { error: "We could not find that stationery request." },
          { status: 404 },
        );
      }

      if (existingRequest.status !== "awaiting_payment") {
        return jsonResponse(
          { error: "This stationery request is no longer awaiting payment." },
          { status: 400 },
        );
      }

      stationeryRequest = existingRequest as StationeryRequestRow;
      normalizedItems = normalizeItems(existingRequest.items);
      amount = Number(existingRequest.amount ?? 0);
      if (!Number.isFinite(amount) || amount <= 0) {
        amount = calculateAmount(normalizedItems);
      }
      deliveryAddress = existingRequest.delivery_address;
      notes = existingRequest.notes;
    } else {
      const normalizedShopId = typeof body.shopId === "string"
        ? body.shopId.trim()
        : "";
      if (!normalizedShopId || normalizedShopId !== shop.id) {
        return jsonResponse(
          { error: "Invalid shop for stationery checkout." },
          { status: 400 },
        );
      }

      normalizedItems = normalizeItems(body.items);
      if (normalizedItems.length === 0) {
        return jsonResponse(
          { error: "Choose at least one stationery item before paying." },
          { status: 400 },
        );
      }

      amount = calculateAmount(normalizedItems);
      if (amount <= 0) {
        return jsonResponse(
          { error: "The stationery total must be greater than zero." },
          { status: 400 },
        );
      }

      deliveryAddress = typeof body.deliveryAddress === "string"
        ? body.deliveryAddress.trim() || null
        : null;
      notes = typeof body.notes === "string" ? body.notes.trim() || null : null;

      const { data: insertedRequest, error: insertError } = await admin
        .from("stationery_requests")
        .insert({
          shop_id: shop.id,
          vendor_id: user.id,
          items: normalizedItems.map((item) => ({
            key: item.key,
            name: item.name,
            quantity: item.quantity,
          })),
          notes,
          delivery_address: deliveryAddress,
          amount,
          currency: "ZAR",
          status: "awaiting_payment",
          status_reason: null,
        })
        .select(
          "id, shop_id, vendor_id, items, delivery_address, notes, status, amount",
        )
        .single();

      if (insertError != null || insertedRequest == null) {
        return jsonResponse(
          { error: insertError?.message ?? "Could not create stationery request." },
          { status: 500 },
        );
      }

      stationeryRequest = insertedRequest as StationeryRequestRow;
    }

    const checkoutReference = crypto.randomUUID();
    const paymentReference =
      `stationery-${stationeryRequest.id}-${checkoutReference}`;
    const displayName = firstNonEmptyString(profile?.display_name, shop.name) ??
      "Artisan Lane Vendor";
    const email = firstNonEmptyString(profile?.email) ??
      `${user.id}@artisanlane.local`;
    const notifyUrl = `${supabaseUrl}/functions/v1/payfast-itn`;
    const totalQuantity = normalizedItems.reduce(
      (sum, item) => sum + item.quantity,
      0,
    );

    const { error: updateError } = await admin
      .from("stationery_requests")
      .update({
        amount,
        currency: "ZAR",
        checkout_reference: checkoutReference,
        payment_reference: paymentReference,
        payfast_email: email,
        status: "awaiting_payment",
        status_reason: null,
      })
      .eq("id", stationeryRequest.id)
      .eq("vendor_id", user.id);

    if (updateError != null) {
      return jsonResponse(
        { error: updateError.message },
        { status: 500 },
      );
    }

    const checkoutUrl = buildPayFastOnceOffCheckoutUrl({
      amount,
      itemName: "Artisan Lane Stationery",
      itemDescription:
        `${totalQuantity} branded stationery item(s) for ${shop.name}`,
      reference: paymentReference,
      email,
      displayName,
      returnUrl: stationeryReturnUrl,
      cancelUrl: stationeryCancelUrl,
      notifyUrl,
      customStrings: [
        "stationery_request",
        stationeryRequest.id,
        user.id,
        checkoutReference,
      ],
    });

    return jsonResponse({
      requestId: stationeryRequest.id,
      checkoutUrl,
      checkoutReference,
      amount,
      currency: "ZAR",
      status: "awaiting_payment",
      deliveryAddress,
      notes,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Could not create stationery checkout.",
      },
      { status: 500 },
    );
  }
});
