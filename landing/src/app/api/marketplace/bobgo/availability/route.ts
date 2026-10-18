import { NextResponse } from "next/server";

import { checkBobGoCartEligibility, normalizeCartItems } from "@/lib/bobgo-eligibility";
import { createAdminClient } from "@/lib/supabase/admin";

/**
 * Whether Bob Go can be offered for this cart (server flag on, artisan opted
 * in with complete collection details, every product has parcel
 * measurements). Never calls Bob Go and never reveals the collection address.
 * Mirrors the app's bobgo-quote `availability` action.
 */
export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as { items?: unknown } | null;
  const items = normalizeCartItems(body?.items);
  try {
    const eligibility = await checkBobGoCartEligibility(createAdminClient(), items);
    return NextResponse.json(
      eligibility.available ? { available: true } : { available: false, reason: eligibility.reason },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch {
    return NextResponse.json({ available: false, reason: "unavailable" }, { headers: { "Cache-Control": "no-store" } });
  }
}
