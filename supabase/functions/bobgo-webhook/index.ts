// Receives Bob Go tracking webhooks (topic tracking/updated) and stores the
// latest courier status on the order. Configure the webhook in Bob Go with the
// URL  https://<project>.functions.supabase.co/bobgo-webhook?secret=<BOBGO_WEBHOOK_SECRET>
// (see docs/bobgo-go-live.md). verify_jwt is disabled for this function in
// supabase/config.toml, so the shared secret is the only gate.

import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse } from "../_shared/http.ts";
import { applyBobGoTrackingSnapshot, BOBGO_ORDER_TRACKING_COLUMNS } from "../_shared/bobgo-sync.ts";
import { isValidWebhookSecret, parseBobGoTrackingPayload } from "../_shared/bobgo-tracking.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const webhookSecret = Deno.env.get("BOBGO_WEBHOOK_SECRET");
const MAX_BODY_BYTES = 128 * 1024;

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, { status: 405 });
    }
    const supplied = new URL(request.url).searchParams.get("secret") ??
      request.headers.get("x-bobgo-webhook-secret");
    if (!isValidWebhookSecret(supplied ?? "", webhookSecret ?? "")) {
      return jsonResponse({ error: "Unauthorized." }, { status: 401 });
    }

    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Payload too large." }, { status: 413 });
    }
    let payload: unknown;
    try {
      payload = JSON.parse(raw);
    } catch (_) {
      return jsonResponse({ error: "Invalid JSON." }, { status: 400 });
    }

    const snapshot = parseBobGoTrackingPayload(payload);
    if (!snapshot) {
      // Other topics (e.g. shipment_submission_status/updated) are acknowledged
      // so Bob Go does not retry; the poller reconciles anything we skip.
      return jsonResponse({ ok: true, ignored: true, reason: "unrecognised_payload" });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: order } = await admin
      .from("orders")
      .select(BOBGO_ORDER_TRACKING_COLUMNS)
      .eq("shipping_method", "bobgo_door_to_door")
      .eq("tracking_number", snapshot.trackingReference)
      .maybeSingle();
    if (!order) return jsonResponse({ ok: true, ignored: true, reason: "unknown_shipment" });

    const changed = await applyBobGoTrackingSnapshot(admin, order, snapshot);
    return jsonResponse({ ok: true, changed });
  } catch (error) {
    console.error("[bobgo-webhook] failed", error);
    // 500 makes Bob Go retry, which is what we want for transient DB errors.
    return jsonResponse({ error: "Webhook processing failed." }, { status: 500 });
  }
});
