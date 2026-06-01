import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  receiptReminderEventKey,
  receiptReminderKey,
  shouldSendReceiptReminder,
} from "./receipt-reminders.ts";

Deno.test("receipt reminders start three days after shipping and repeat every three days", () => {
  assertEquals(
    receiptReminderKey({
      now: new Date("2026-05-18T10:00:00.000Z"),
      shippedAt: "2026-05-16T10:00:00.000Z",
    }),
    null,
  );
  assertEquals(
    receiptReminderKey({
      now: new Date("2026-05-18T10:00:00.000Z"),
      shippedAt: "2026-05-15T10:00:00.000Z",
    }),
    "day-3",
  );
  assertEquals(
    receiptReminderKey({
      now: new Date("2026-05-21T10:00:00.000Z"),
      shippedAt: "2026-05-15T10:00:00.000Z",
    }),
    "day-6",
  );
});

Deno.test("receipt reminders skip completed and already-reminded orders", () => {
  const now = new Date("2026-05-21T10:00:00.000Z");
  const order = {
    id: "order-1",
    buyer_id: "buyer-1",
    status: "shipped",
    shipped_at: "2026-05-15T10:00:00.000Z",
    received_at: null,
  };
  const eventKey = receiptReminderEventKey({
    orderId: order.id,
    reminderKey: "day-6",
  });

  assertEquals(
    shouldSendReceiptReminder({
      order,
      now,
      existingEventKeys: new Set<string>(),
    }),
    { shouldSend: true, reminderKey: "day-6", eventKey },
  );
  assertEquals(
    shouldSendReceiptReminder({
      order,
      now,
      existingEventKeys: new Set([eventKey]),
    }).shouldSend,
    false,
  );
  assertEquals(
    shouldSendReceiptReminder({
      order: { ...order, status: "completed", received_at: now.toISOString() },
      now,
      existingEventKeys: new Set<string>(),
    }).shouldSend,
    false,
  );
});
