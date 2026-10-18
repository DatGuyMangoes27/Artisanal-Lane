// Receives Bob Go webhooks and stores the latest courier state on the order.
//
// Topics handled (subscribe with POST /webhooks, see docs/bobgo-go-live.md):
//   tracking/updated                    -> courier status + checkpoints
//   shipment_submission_status/updated  -> courier refused the booking
//   shipment_charged_amount/updated     -> final courier charge
// Anything else is acknowledged with 200 so Bob Go does not retry or disable
// the subscription; bobgo-sync-tracking reconciles anything skipped.
//
// Authentication (verify_jwt is off in config.toml, so this is the only gate):
//   - preferred: `Bobgo-Webhook-Signature` = base64 HMAC-SHA256 of the raw
//     body keyed with BOBGO_WEBHOOK_SECRET (the secret generated in the Bob Go
//     dashboard under Settings -> Webhook subscriptions);
//   - fallback while that header is unconfirmed in the sandbox: the same secret
//     in the `x-bobgo-webhook-secret` header or `?secret=` query parameter.
//     Set BOBGO_WEBHOOK_REQUIRE_SIGNATURE=true once signatures are confirmed to
//     turn the fallback off.
// Replays and out-of-order events are ignored (see buildOrderTrackingUpdate).

import { createClient } from "npm:@supabase/supabase-js@2";

import { jsonResponse } from "../_shared/http.ts";
import { applyBobGoTrackingSnapshot, BOBGO_ORDER_TRACKING_COLUMNS } from "../_shared/bobgo-sync.ts";
import {
  isFailedBobGoSubmission,
  isValidWebhookSecret,
  parseBobGoTrackingPayload,
  verifyBobGoWebhookSignature,
} from "../_shared/bobgo-tracking.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const webhookSecret = Deno.env.get("BOBGO_WEBHOOK_SECRET") ?? "";
const requireSignature = Deno.env.get("BOBGO_WEBHOOK_REQUIRE_SIGNATURE") === "true";
const MAX_BODY_BYTES = 256 * 1024;

async function isAuthorized(request: Request, raw: string) {
  if (!webhookSecret) return false;
  const signature = request.headers.get("bobgo-webhook-signature");
  if (signature) return await verifyBobGoWebhookSignature(raw, signature, webhookSecret);
  if (requireSignature) return false;
  const supplied = request.headers.get("x-bobgo-webhook-secret") ??
    new URL(request.url).searchParams.get("secret") ?? "";
  return isValidWebhookSecret(supplied, webhookSecret);
}

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, { status: 405 });
    }
    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (declaredLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Payload too large." }, { status: 413 });
    }
    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Payload too large." }, { status: 413 });
    }
    if (!(await isAuthorized(request, raw))) {
      return jsonResponse({ error: "Unauthorized." }, { status: 401 });
    }

    let payload: unknown;
    try {
      payload = JSON.parse(raw);
    } catch (_) {
      return jsonResponse({ error: "Invalid JSON." }, { status: 400 });
    }

    const snapshot = parseBobGoTrackingPayload(payload);
    if (!snapshot) {
      return jsonResponse({ ok: true, ignored: true, reason: "unrecognised_payload" });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const findBy = (column: string, value: string) =>
      admin
        .from("orders")
        .select(BOBGO_ORDER_TRACKING_COLUMNS)
        .eq("shipping_method", "bobgo_door_to_door")
        .eq(column, value)
        .limit(1)
        .maybeSingle();

    let { data: order } = await findBy("tracking_number", snapshot.trackingReference);
    if (!order && snapshot.shipmentId) {
      ({ data: order } = await findBy("bobgo_shipment_id", snapshot.shipmentId));
    }
    if (!order) return jsonResponse({ ok: true, ignored: true, reason: "unknown_shipment" });

    // The courier refused the booking after Bob Go accepted it (submission
    // status failed-indefinitely / no-rates): Bob Go will never deliver it. If
    // the parcel has not been handed over yet, release the order for a fresh
    // booking (retry button / sync sweep; the failed shipment is skipped by the
    // duplicate lookup). Otherwise just record it for an admin.
    if (isFailedBobGoSubmission(snapshot.submissionStatus)) {
      const reason = (snapshot.failedReason ?? "The courier could not accept this shipment.")
        .slice(0, 300);
      const error = `Courier refused shipment ${order.bobgo_shipment_id ?? snapshot.shipmentId ?? ""}: ${reason}`;
      const { data: released } = await admin
        .from("orders")
        .update({
          bobgo_booking_state: "failed",
          bobgo_booking_error: error,
          bobgo_shipment_id: null,
          tracking_number: null,
          tracking_url: null,
          bobgo_tracking_url: null,
          bobgo_status: null,
          bobgo_status_detail: null,
        })
        .eq("id", order.id)
        .eq("status", "paid")
        .eq("bobgo_booking_state", "booked")
        .select("id")
        .maybeSingle();
      if (!released) {
        await admin.from("orders").update({ bobgo_booking_error: error }).eq("id", order.id);
      }
      console.error(`[bobgo] order ${order.id} courier submission failed: ${reason}`);
      return jsonResponse({ ok: true, changed: true });
    }

    const changed = await applyBobGoTrackingSnapshot(admin, order, snapshot);
    return jsonResponse({ ok: true, changed });
  } catch (error) {
    console.error("[bobgo-webhook] failed", error instanceof Error ? error.message : error);
    // 500 makes Bob Go retry, which is what we want for transient DB errors.
    return jsonResponse({ error: "Webhook processing failed." }, { status: 500 });
  }
});
