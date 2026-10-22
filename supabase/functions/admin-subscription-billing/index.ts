import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import {
  fetchPayFastSubscription,
  updatePayFastSubscription,
} from "../_shared/payfast.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Admin-only billing changes for artisan subscriptions.
 * - preview: returns what PayFast and Artisan Lane hold for the vendor.
 * - apply: changes the recurring amount and/or next charge date in PayFast,
 *   then mirrors it on vendor_subscriptions (amount, plan, period end).
 */
Deno.serve(async (request) => {
  try {
    const jwt = getBearerToken(request);
    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: authError } = await client.auth.getUser();
    if (authError != null || user?.id == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: caller } = await admin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();
    if (caller?.role !== "admin") {
      return jsonResponse({ error: "Only an admin can change billing." }, {
        status: 403,
      });
    }

    const body = await request.json().catch(() => ({}));
    const action = body?.action;
    const vendorId = typeof body?.vendorId === "string" ? body.vendorId : "";
    if (!UUID.test(vendorId)) {
      return jsonResponse({ error: "A valid vendorId is required." }, {
        status: 400,
      });
    }

    const { data: subscription, error: loadError } = await admin
      .from("vendor_subscriptions")
      .select(
        "vendor_id, status, plan_code, amount, payfast_token, current_period_end, status_reason",
      )
      .eq("vendor_id", vendorId)
      .maybeSingle();
    if (loadError != null) {
      return jsonResponse({ error: "Could not load the subscription." }, {
        status: 500,
      });
    }
    if (subscription == null || subscription.payfast_token == null) {
      return jsonResponse(
        { error: "This shop has no PayFast subscription to change." },
        { status: 404 },
      );
    }

    const before = await fetchPayFastSubscription(subscription.payfast_token);

    if (action === "preview") {
      return jsonResponse({
        local: subscription,
        payfast: {
          ok: before.ok,
          amount: before.amountCents == null ? null : before.amountCents / 100,
          runDate: before.runDate,
          status: before.statusText,
        },
      });
    }

    if (action !== "apply") {
      return jsonResponse({ error: "Unknown action." }, { status: 400 });
    }

    const amount = body?.amount == null ? null : Number(body.amount);
    const runDate = typeof body?.runDate === "string" ? body.runDate : null;
    const planCode = typeof body?.planCode === "string" ? body.planCode : null;
    const note = typeof body?.note === "string" ? body.note.slice(0, 300) : "";
    if (amount == null && runDate == null) {
      return jsonResponse({ error: "Give a new amount and/or next charge date." }, {
        status: 400,
      });
    }
    if (runDate != null) {
      const today = new Date().toISOString().slice(0, 10);
      if (!DAY.test(runDate) || runDate <= today) {
        return jsonResponse(
          { error: "The next charge date must be a future date (YYYY-MM-DD)." },
          { status: 400 },
        );
      }
    }
    if (!before.ok) {
      return jsonResponse(
        { error: "PayFast could not find this subscription, so nothing was changed." },
        { status: 502 },
      );
    }

    const result = await updatePayFastSubscription(subscription.payfast_token, {
      amountRands: amount,
      runDate,
    });
    if (!result.ok) {
      // PayFast answers 200 with {status: "failed", data: {response: "..."}}
      // and its reason is the only clue, so log it and show it to the admin.
      const payfastBody = result.body as
        | { data?: { response?: unknown; message?: unknown }; message?: unknown }
        | string
        | null;
      const reasonValue = typeof payfastBody === "string"
        ? payfastBody
        : payfastBody?.data?.response ?? payfastBody?.data?.message ?? payfastBody?.message;
      const reason = typeof reasonValue === "string"
        ? reasonValue.slice(0, 300)
        : reasonValue != null
        ? JSON.stringify(reasonValue).slice(0, 300)
        : null;
      console.error("admin-subscription-billing: PayFast update failed", {
        vendorId,
        status: result.status,
        reason,
        payfastStatus: before.statusText,
      });
      return jsonResponse(
        {
          error: reason
            ? `PayFast rejected the change: ${reason}. Nothing was changed.`
            : "PayFast rejected the change. Nothing was changed.",
          payfast: result.body,
        },
        { status: 502 },
      );
    }
    const after = await fetchPayFastSubscription(subscription.payfast_token);

    const reason = [
      `Billing changed by admin${note ? `: ${note}` : ""}.`,
      amount != null ? `Amount R${amount.toFixed(2)}.` : "",
      runDate != null ? `Next charge ${runDate}.` : "",
    ].filter(Boolean).join(" ");
    const { error: saveError } = await admin
      .from("vendor_subscriptions")
      .update({
        ...(amount != null ? { amount } : {}),
        ...(planCode != null ? { plan_code: planCode } : {}),
        // Access runs until the next charge.
        ...(runDate != null
          ? { current_period_end: new Date(`${runDate}T00:00:00Z`).toISOString() }
          : {}),
        status_reason: reason,
      })
      .eq("vendor_id", vendorId);
    if (saveError != null) {
      return jsonResponse(
        {
          error:
            "PayFast was updated, but Artisan Lane could not save the change. Update the shop's record manually.",
          payfast: { amount: after.amountCents, runDate: after.runDate },
        },
        { status: 500 },
      );
    }

    console.log("admin-subscription-billing applied", {
      vendorId,
      adminId: user.id,
      amount,
      runDate,
    });
    return jsonResponse({
      ok: true,
      before: {
        amount: before.amountCents == null ? null : before.amountCents / 100,
        runDate: before.runDate,
      },
      after: {
        amount: after.amountCents == null ? null : after.amountCents / 100,
        runDate: after.runDate,
      },
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Could not change billing." },
      { status: 500 },
    );
  }
});
