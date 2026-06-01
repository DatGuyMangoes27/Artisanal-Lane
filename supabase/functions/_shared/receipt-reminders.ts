export type ReceiptReminderOrder = {
  id: string;
  buyer_id: string;
  status: string;
  shipped_at: string | null;
  received_at: string | null;
};

const reminderIntervalDays = 3;

export function receiptReminderKey({
  now,
  shippedAt,
}: {
  now: Date;
  shippedAt: string | null;
}) {
  if (shippedAt == null) return null;

  const shippedTime = new Date(shippedAt).getTime();
  if (!Number.isFinite(shippedTime)) return null;

  const elapsedMs = now.getTime() - shippedTime;
  const elapsedDays = Math.floor(elapsedMs / (24 * 60 * 60 * 1000));
  if (elapsedDays < reminderIntervalDays) return null;

  const reminderDay = Math.floor(elapsedDays / reminderIntervalDays) *
    reminderIntervalDays;
  return `day-${reminderDay}`;
}

export function receiptReminderEventKey({
  orderId,
  reminderKey,
}: {
  orderId: string;
  reminderKey: string;
}) {
  return `order_update:${orderId}:receipt_reminder:${reminderKey}:buyer`;
}

export function shouldSendReceiptReminder({
  order,
  now,
  existingEventKeys,
}: {
  order: ReceiptReminderOrder;
  now: Date;
  existingEventKeys: Set<string>;
}) {
  const status = order.status.toLowerCase();
  const reminderKey = receiptReminderKey({ now, shippedAt: order.shipped_at });
  const eventKey = reminderKey == null
    ? null
    : receiptReminderEventKey({ orderId: order.id, reminderKey });

  const shouldSend = (status === "shipped" || status === "delivered") &&
    order.received_at == null &&
    reminderKey != null &&
    eventKey != null &&
    !existingEventKeys.has(eventKey);

  return { shouldSend, reminderKey, eventKey };
}
