import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildChatMessagePush,
  buildDisputePush,
  buildOrderPush,
  recipientForChatMessage,
} from "./push.ts";

Deno.test("chat push recipient is the other buyer/vendor participant", () => {
  const thread = {
    id: "thread-1",
    buyer_id: "buyer-1",
    vendor_id: "vendor-1",
    kind: "buyer_vendor",
    shops: { name: "Clay Studio" },
  };

  assertEquals(
    recipientForChatMessage(thread, "buyer-1"),
    { userId: "vendor-1", role: "vendor" },
  );
  assertEquals(
    recipientForChatMessage(thread, "vendor-1"),
    { userId: "buyer-1", role: "buyer" },
  );
});

Deno.test("chat push recipient for admin shop messages is the vendor", () => {
  assertEquals(
    recipientForChatMessage(
      {
        id: "thread-1",
        buyer_id: "admin-1",
        vendor_id: "vendor-1",
        kind: "admin_vendor",
        shops: { name: "Clay Studio" },
      },
      "admin-1",
    ),
    { userId: "vendor-1", role: "vendor" },
  );
});

Deno.test("chat push payload includes route data and attachment fallback", () => {
  const payload = buildChatMessagePush({
    threadId: "thread-1",
    messageId: "message-1",
    recipientRole: "vendor",
    senderLabel: "Artisan Lane Admin",
    body: null,
    messageType: "attachment",
  });

  assertEquals(payload, {
    title: "New message from Artisan Lane Admin",
    body: "Sent an attachment",
    data: {
      type: "chat_message",
      thread_id: "thread-1",
      message_id: "message-1",
      recipient_role: "vendor",
    },
  });
});

Deno.test("order push payload targets vendor for paid orders", () => {
  const payload = buildOrderPush({
    event: "paid",
    orderId: "order-1",
    recipientRole: "vendor",
    shopName: "Clay Studio",
  });

  assertEquals(payload, {
    title: "New order received",
    body: "You have a new paid order for Clay Studio.",
    data: {
      type: "order_update",
      order_id: "order-1",
      event: "paid",
      recipient_role: "vendor",
    },
  });
});

Deno.test("order push payload includes tracking fallback for buyers", () => {
  const payload = buildOrderPush({
    event: "shipped",
    orderId: "order-1",
    recipientRole: "buyer",
    shopName: "Clay Studio",
    trackingNumber: "TRACK123",
  });

  assertEquals(
    payload.body,
    "Clay Studio shipped your order. Tracking: TRACK123",
  );
  assertEquals(payload.data.event, "shipped");
});

Deno.test("dispute push payload routes to the dispute order", () => {
  const payload = buildDisputePush({
    event: "opened",
    orderId: "order-1",
    disputeId: "dispute-1",
    recipientRole: "vendor",
    shopName: "Clay Studio",
  });

  assertEquals(payload, {
    title: "Dispute opened",
    body: "A dispute was opened for an order from Clay Studio.",
    data: {
      type: "dispute_update",
      order_id: "order-1",
      dispute_id: "dispute-1",
      event: "opened",
      recipient_role: "vendor",
    },
  });
});
