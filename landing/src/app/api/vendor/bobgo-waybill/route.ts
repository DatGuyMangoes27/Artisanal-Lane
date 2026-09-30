import { NextResponse } from "next/server";

import { fetchBobGoWaybill } from "@/lib/bobgo";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

function bobGoEnabled() {
  return process.env.BOBGO_SHIPPING_ENABLED === "true" ||
    (process.env.NODE_ENV === "development" && Boolean(process.env.BOBGO_SANDBOX_API_KEY));
}

/** Streams the courier waybill PDF to the artisan who owns the order. */
export async function GET(request: Request) {
  if (!bobGoEnabled()) {
    return NextResponse.json({ error: "Bob Go delivery is disabled." }, { status: 404 });
  }

  const orderId = new URL(request.url).searchParams.get("orderId")?.trim();
  if (!orderId) return NextResponse.json({ error: "Missing order." }, { status: 400 });

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Sign in to continue." }, { status: 401 });

  const admin = createAdminClient();
  const { data: order } = await admin
    .from("orders")
    .select("id, shop_id, shipping_method, tracking_number, bobgo_booking_state, shops!inner(vendor_id)")
    .eq("id", orderId)
    .maybeSingle();

  const shop = Array.isArray(order?.shops) ? order?.shops[0] : order?.shops;
  if (!order || order.shipping_method !== "bobgo_door_to_door" || shop?.vendor_id !== user.id) {
    return NextResponse.json({ error: "Order not found." }, { status: 404 });
  }
  if (order.bobgo_booking_state !== "booked" || !order.tracking_number) {
    return NextResponse.json({ error: "The courier has not been booked yet." }, { status: 409 });
  }

  try {
    const waybill = await fetchBobGoWaybill(order.tracking_number);
    return new NextResponse(waybill.body, {
      headers: {
        "Content-Type": waybill.contentType,
        "Content-Disposition": `inline; filename="waybill-${order.tracking_number}.pdf"`,
        "Cache-Control": "private, no-store",
      },
    });
  } catch {
    return NextResponse.json({ error: "The waybill is not available right now." }, { status: 502 });
  }
}
