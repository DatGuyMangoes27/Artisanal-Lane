import { NextResponse } from "next/server";

import { createAdminClient } from "@/lib/supabase/admin";

type ReservationRequest = {
  action?: unknown;
  reservationToken?: unknown;
  productId?: unknown;
  variantId?: unknown;
  quantity?: unknown;
};

function stringOrNull(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function numberOrNull(value: unknown) {
  const numberValue = typeof value === "number" ? value : Number(value);
  return Number.isFinite(numberValue) ? Math.trunc(numberValue) : null;
}

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as ReservationRequest | null;
  const action = stringOrNull(body?.action);
  const reservationToken = stringOrNull(body?.reservationToken);

  if (!reservationToken) {
    return NextResponse.json({ error: "Reservation token is required." }, { status: 400 });
  }

  const admin = createAdminClient();

  if (action === "releaseAll") {
    const { data, error } = await admin.rpc("release_all_product_reservations", {
      reservation_token_input: reservationToken,
      next_status: "released",
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 409 });
    }

    return NextResponse.json({ restoredQuantity: data ?? 0 });
  }

  const productId = stringOrNull(body?.productId);
  const variantId = stringOrNull(body?.variantId);

  if (!productId) {
    return NextResponse.json({ error: "Product ID is required." }, { status: 400 });
  }

  if (action === "release") {
    const { data, error } = await admin.rpc("release_product_reservation", {
      reservation_token_input: reservationToken,
      product_id_input: productId,
      variant_id_input: variantId,
      next_status: "released",
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 409 });
    }

    return NextResponse.json({ restoredQuantity: data ?? 0 });
  }

  if (action === "reserve") {
    const quantity = numberOrNull(body?.quantity);
    if (quantity == null || quantity <= 0) {
      return NextResponse.json({ error: "Reservation quantity must be greater than zero." }, { status: 400 });
    }

    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString();
    const { data, error } = await admin.rpc("reserve_product_stock", {
      reservation_token_input: reservationToken,
      product_id_input: productId,
      variant_id_input: variantId,
      quantity_input: quantity,
      expires_at_input: expiresAt,
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 409 });
    }

    return NextResponse.json({ reservation: Array.isArray(data) ? data[0] : data });
  }

  return NextResponse.json({ error: "Unsupported reservation action." }, { status: 400 });
}
