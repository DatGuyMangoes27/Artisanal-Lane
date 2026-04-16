import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { disputeAllocationDelivery } from "../_shared/tradesafe.ts";
import { prepareDisputeOpen } from "../_shared/dispute-workflow.mjs";
import { normalizeRequestUserId, resolveRequestUserId } from "../_shared/request-auth.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (request) => {
  try {
    const body = await request.json();
    const orderId = body.orderId as string;
    const reason = (body.reason as string | undefined)?.trim() ?? "";
    const requestUserId = normalizeRequestUserId(body.userId);

    let userId = requestUserId;
    const authHeader = request.headers.get("Authorization");

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
          userId = resolveRequestUserId({
            requestUserId,
            resolvedUserId: user.id,
          });
        }
      } catch (_) {
        // Fall back to the app-provided user ID when JWT verification is disabled.
      }
    }

    if (userId == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    if (reason.length == 0) {
      return jsonResponse({ error: "A dispute reason is required." }, { status: 400 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: order } = await admin
      .from("orders")
      .select("id, buyer_id, shop_id, tradesafe_allocation_id")
      .eq("id", orderId)
      .single();

    if (order.buyer_id != userId) {
      return jsonResponse({ error: "You cannot dispute this order." }, { status: 403 });
    }

    const [{ data: shop }, { data: activeDisputeRow }, { data: adminProfiles }] =
      await Promise.all([
        admin
          .from("shops")
          .select("vendor_id")
          .eq("id", order.shop_id as string)
          .single(),
        admin
          .from("disputes")
          .select("id, status, dispute_conversations(id)")
          .eq("order_id", orderId)
          .in("status", ["open", "investigating"])
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle(),
        admin.from("profiles").select("id").eq("role", "admin"),
      ]);

    const sellerId = shop?.vendor_id as string | null;
    if (sellerId == null) {
      return jsonResponse({ error: "This order is missing a seller account." }, { status: 400 });
    }

    const existingConversation = Array.isArray(activeDisputeRow?.dispute_conversations)
      ? activeDisputeRow.dispute_conversations[0]
      : activeDisputeRow?.dispute_conversations;
    const workflow = prepareDisputeOpen({
      orderId,
      buyerId: userId,
      sellerId,
      reason,
      adminIds: (adminProfiles ?? []).map((profile) => profile.id as string),
      existingDispute: activeDisputeRow == null
        ? null
        : {
            id: activeDisputeRow.id as string,
            status: activeDisputeRow.status as string,
            conversationId: existingConversation?.id as string | undefined,
          },
    });

    if (workflow.reuseExisting) {
      return jsonResponse({
        ok: true,
        disputeId: workflow.disputeId,
        conversationId: workflow.conversationId,
        reused: true,
      });
    }

    if (order.tradesafe_allocation_id) {
      await disputeAllocationDelivery(order.tradesafe_allocation_id as string, reason);
    }

    let createdDispute = workflow.disputeId == null ? null : { id: workflow.disputeId };
    if (workflow.createDispute != null) {
      const { data, error: disputeInsertError } = await admin
        .from("disputes")
        .insert(workflow.createDispute)
        .select("id")
        .single();

      if (disputeInsertError != null || data == null) {
        throw disputeInsertError ?? new Error("Unable to create dispute record.");
      }
      createdDispute = data;
    }

    if (createdDispute == null) {
      throw new Error("Unable to determine the dispute record.");
    }

    const { error: conversationInsertError } = await admin
      .from("dispute_conversations")
      .insert({
        ...workflow.createConversation,
        dispute_id: createdDispute.id,
      });

    if (conversationInsertError != null) {
      throw conversationInsertError;
    }

    const { error: participantsInsertError } = await admin
      .from("dispute_conversation_participants")
      .insert(workflow.participants);

    if (participantsInsertError != null) {
      throw participantsInsertError;
    }

    const { error: initialMessageInsertError } = await admin
      .from("dispute_conversation_messages")
      .insert(workflow.createInitialMessage);

    if (initialMessageInsertError != null) {
      throw initialMessageInsertError;
    }

    await admin
      .from("orders")
      .update({
        status: "disputed",
        payment_state: "disputed",
      })
      .eq("id", orderId);

    return jsonResponse({
      ok: true,
      disputeId: createdDispute.id,
      conversationId: workflow.conversationId,
      reused: false,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Unable to open dispute.",
      },
      { status: 500 },
    );
  }
});
