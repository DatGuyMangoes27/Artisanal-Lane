import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import {
  receiptReminderEventKey,
  shouldSendReceiptReminder,
  type ReceiptReminderOrder,
} from "../_shared/receipt-reminders.ts";
import { sendInternalPushRequest } from "../_shared/push.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const reminderSecret = Deno.env.get("RECEIPT_REMINDER_SECRET");

function isAuthorized(request: Request) {
  if (reminderSecret) {
    return request.headers.get("x-receipt-reminder-secret") === reminderSecret;
  }

  try {
    return getBearerToken(request) === supabaseServiceRoleKey;
  } catch (_) {
    return false;
  }
}

Deno.serve(async (request) => {
  try {
    if (!isAuthorized(request)) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const now = new Date();
    const earliestReminderDate = new Date(
      now.getTime() - 3 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: orders, error: ordersError } = await admin
      .from("orders")
      .select("id, buyer_id, status, shipped_at, received_at")
      .in("status", ["shipped", "delivered"])
      .is("received_at", null)
      .not("shipped_at", "is", null)
      .lte("shipped_at", earliestReminderDate);

    if (ordersError) {
      throw new Error(ordersError.message);
    }

    const candidates = ((orders ?? []) as ReceiptReminderOrder[])
      .map((order) => {
        const check = shouldSendReceiptReminder({
          order,
          now,
          existingEventKeys: new Set<string>(),
        });
        return { order, ...check };
      })
      .filter((candidate) =>
        candidate.reminderKey != null && candidate.eventKey != null
      );

    const candidateEventKeys = candidates.map((candidate) =>
      candidate.eventKey!
    );
    const existingEventKeys = new Set<string>();
    if (candidateEventKeys.length > 0) {
      const { data: notifications, error: notificationError } = await admin
        .from("notifications")
        .select("event_key")
        .in("event_key", candidateEventKeys);

      if (notificationError) {
        throw new Error(notificationError.message);
      }

      for (const notification of notifications ?? []) {
        const eventKey = notification.event_key;
        if (typeof eventKey === "string") {
          existingEventKeys.add(eventKey);
        }
      }
    }

    const reminded: string[] = [];
    const skipped: string[] = [];

    for (const candidate of candidates) {
      const result = shouldSendReceiptReminder({
        order: candidate.order,
        now,
        existingEventKeys,
      });

      if (!result.shouldSend || result.reminderKey == null) {
        skipped.push(candidate.order.id);
        continue;
      }

      await sendInternalPushRequest({
        supabaseUrl,
        serviceRoleKey: supabaseServiceRoleKey,
        body: {
          type: "order_update",
          orderId: candidate.order.id,
          event: "receipt_reminder",
          reminderKey: result.reminderKey,
        },
      });
      reminded.push(candidate.order.id);
      existingEventKeys.add(
        receiptReminderEventKey({
          orderId: candidate.order.id,
          reminderKey: result.reminderKey,
        }),
      );
    }

    return jsonResponse({
      ok: true,
      checked: orders?.length ?? 0,
      reminded,
      skipped,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Unable to send receipt reminders.",
      },
      { status: 500 },
    );
  }
});
