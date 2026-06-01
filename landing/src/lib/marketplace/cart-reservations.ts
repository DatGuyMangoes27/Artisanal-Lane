"use client";

export const guestCartReservationTokenKey = "artisan-lane-guest-cart-reservation-token";

function createReservationToken() {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

export function getGuestCartReservationToken() {
  let token = window.localStorage.getItem(guestCartReservationTokenKey);
  if (!token) {
    token = createReservationToken();
    window.localStorage.setItem(guestCartReservationTokenKey, token);
  }

  return token;
}

export function clearGuestCartReservationToken() {
  window.localStorage.removeItem(guestCartReservationTokenKey);
}

async function postReservationAction(body: Record<string, unknown>) {
  const response = await fetch("/api/marketplace/reservations/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const payload = (await response.json().catch(() => null)) as { error?: string } | null;

  if (!response.ok || payload?.error) {
    throw new Error(payload?.error ?? "Could not update cart reservation.");
  }

  return payload;
}

export async function reserveGuestCartItem({
  productId,
  quantity,
  variantId = null,
}: {
  productId: string;
  quantity: number;
  variantId?: string | null;
}) {
  return postReservationAction({
    action: "reserve",
    reservationToken: getGuestCartReservationToken(),
    productId,
    variantId,
    quantity,
  });
}

export async function releaseGuestCartItem({
  productId,
  variantId = null,
}: {
  productId: string;
  variantId?: string | null;
}) {
  return postReservationAction({
    action: "release",
    reservationToken: getGuestCartReservationToken(),
    productId,
    variantId,
  });
}

export async function releaseAllGuestCartReservations() {
  const token = window.localStorage.getItem(guestCartReservationTokenKey);
  if (!token) {
    return null;
  }

  const payload = await postReservationAction({
    action: "releaseAll",
    reservationToken: token,
  });
  clearGuestCartReservationToken();
  return payload;
}
