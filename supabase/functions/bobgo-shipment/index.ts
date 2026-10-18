// Vendor/admin actions on a Bob Go order:
//   { orderId, action: "waybill" }        -> { fileName, contentType, base64 }
//   { orderId, action: "retry_booking" }  -> retries a failed courier booking
// Requires a valid user JWT belonging to the shop's vendor or an admin.
// Works whenever Bob Go credentials are configured (not only while new Bob Go
// checkouts are switched on), so a rollback never strands a paid order.

import { createClient } from "npm:@supabase/supabase-js@2";

import { fetchBobGoWaybill, isBobGoConfigured } from "../_shared/bobgo.ts";
import { bookBobGoShipmentForOrder } from "../_shared/bobgo-booking.ts";
import { getBearerToken, jsonResponse, optionsResponse } from "../_shared/http.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function toBase64(bytes: Uint8Array) {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

Deno.serve(async (request) => {
  try {
    if (request.method === "OPTIONS") return optionsResponse();
    if (!isBobGoConfigured()) {
      return jsonResponse({ error: "Bob Go delivery is not available right now." }, { status: 404 });
    }

    let userId: string;
    try {
      const client = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: `Bearer ${getBearerToken(request)}` } },
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data, error } = await client.auth.getUser();
      if (error || !data.user) return jsonResponse({ error: "Unauthorized" }, { status: 401 });
      userId = data.user.id;
    } catch (_) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json().catch(() => ({})) as Record<string, unknown>;
    const orderId = typeof body.orderId === "string" ? body.orderId : "";
    const action = typeof body.action === "string" ? body.action : "";
    if (!orderId || !["waybill", "retry_booking"].includes(action)) {
      return jsonResponse({ error: "Unknown request." }, { status: 400 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: order } = await admin
      .from("orders")
      .select(
        "id, shop_id, status, shipping_method, tracking_number, bobgo_quote_id, bobgo_provider_slug, bobgo_service_level_code, bobgo_shipment_id, bobgo_booking_state",
      )
      .eq("id", orderId)
      .maybeSingle();
    if (!order || order.shipping_method !== "bobgo_door_to_door") {
      return jsonResponse({ error: "Order not found." }, { status: 404 });
    }

    const [{ data: shop }, { data: profile }] = await Promise.all([
      admin.from("shops").select("id").eq("id", order.shop_id).eq("vendor_id", userId).maybeSingle(),
      admin.from("profiles").select("role").eq("id", userId).maybeSingle(),
    ]);
    if (!shop && profile?.role !== "admin") {
      return jsonResponse({ error: "You cannot manage this order." }, { status: 403 });
    }

    if (action === "waybill") {
      if (order.bobgo_booking_state !== "booked" || !order.tracking_number) {
        return jsonResponse(
          { error: "The courier has not been booked for this order yet." },
          { status: 409 },
        );
      }
      const waybill = await fetchBobGoWaybill(order.tracking_number as string);
      return jsonResponse({
        fileName: `waybill-${order.tracking_number}.pdf`,
        contentType: waybill.contentType,
        base64: toBase64(waybill.bytes),
      });
    }

    if (!["paid"].includes(order.status as string)) {
      return jsonResponse({ error: "Only paid orders can be booked." }, { status: 409 });
    }
    if (order.bobgo_booking_state === "booking") {
      return jsonResponse(
        { error: "A courier booking is already in progress. Please check again in a few minutes." },
        { status: 409 },
      );
    }
    const result = await bookBobGoShipmentForOrder(admin, order);
    if (result.outcome === "failed") {
      return jsonResponse({ error: "The courier booking failed again. Please try later or contact support." }, {
        status: 502,
      });
    }
    return jsonResponse({ ok: true, outcome: result.outcome });
  } catch (error) {
    console.error("[bobgo-shipment] failed", error);
    return jsonResponse({ error: "Something went wrong. Please try again." }, { status: 500 });
  }
});
