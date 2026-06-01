import { NextResponse } from "next/server";

import { getSupabaseAnonKey, getSupabaseUrl } from "@/lib/supabase/env";

const functionByCarrier = {
  courier_guy: "get-courier-guy-lockers",
  pargo: "get-pargo-pickup-points",
} as const;

type PickupCarrier = keyof typeof functionByCarrier;

function isPickupCarrier(value: unknown): value is PickupCarrier {
  return value === "courier_guy" || value === "pargo";
}

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as {
    carrier?: unknown;
    query?: unknown;
    province?: unknown;
    limit?: unknown;
  } | null;

  if (!isPickupCarrier(body?.carrier)) {
    return NextResponse.json({ error: "Unsupported pickup carrier." }, { status: 400 });
  }

  const response = await fetch(
    `${getSupabaseUrl()}/functions/v1/${functionByCarrier[body.carrier]}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: getSupabaseAnonKey(),
        Authorization: `Bearer ${getSupabaseAnonKey()}`,
      },
      body: JSON.stringify({
        query: typeof body.query === "string" ? body.query : "",
        province: typeof body.province === "string" ? body.province : "",
        limit: typeof body.limit === "number" ? body.limit : 8,
      }),
    },
  );

  const payload = await response.json().catch(() => ({
    error: "Could not read pickup point response.",
  }));

  return NextResponse.json(payload, { status: response.status });
}
