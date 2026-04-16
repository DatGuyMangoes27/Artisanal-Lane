import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { acceptAllocationDelivery } from "../_shared/tradesafe.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (request) => {
  try {
    const body = await request.json();
    const orderId = body.orderId as string;
    const requestUserId =
      typeof body.userId === "string" && body.userId.trim().length > 0
        ? body.userId.trim()
        : null;

    let userId = requestUserId;
    let isAdmin = false;
    const authHeader = request.headers.get("Authorization");

    if (authHeader?.startsWith("Bearer ")) {
      try {
        const jwt = getBearerToken(request);
        const isServiceRoleRequest = jwt == supabaseServiceRoleKey;
        isAdmin = isServiceRoleRequest;

        if (!isServiceRoleRequest) {
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
          }
        }
      } catch (_) {
        // Fall back to the app-provided user ID when JWT verification is disabled.
      }
    }

    if (userId == null && !isAdmin) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const [{ data: profile }, { data: order }] = await Promise.all([
      userId != null
          ? admin.from("profiles").select("role").eq("id", userId).single()
          : Promise.resolve({ data: { role: "admin" } }),
      admin
        .from("orders")
        .select("id, buyer_id, tradesafe_allocation_id")
        .eq("id", orderId)
        .single(),
    ]);

    isAdmin = isAdmin || profile.role == "admin";
    const isBuyer = userId != null && order.buyer_id == userId;

    if (!isAdmin && !isBuyer) {
      return jsonResponse({ error: "You cannot release this escrow." }, { status: 403 });
    }

    let allocationState = "DELIVERY_ACCEPTED";
    if (order.tradesafe_allocation_id) {
      const result = await acceptAllocationDelivery(order.tradesafe_allocation_id as string);
      allocationState = result.allocationAcceptDelivery.state;
    }

    const releasedAt = new Date().toISOString();

    await admin
      .from("orders")
      .update({
        status: "completed",
        payment_state: allocationState,
        received_at: releasedAt,
      })
      .eq("id", orderId);

    await admin
      .from("escrow_transactions")
      .update({
        status: "released",
        provider_state: allocationState,
        released_at: releasedAt,
      })
      .eq("order_id", orderId);

    return jsonResponse({ ok: true, paymentState: allocationState, releasedAt });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Unable to release funds.",
      },
      { status: 500 },
    );
  }
});
