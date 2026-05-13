import { describe, expect, it } from "vitest";

import {
  getMessagePreview,
  getUnreadMessageCount,
  isThreadUnread,
  mapBuyerChatMessage,
  mapBuyerChatThread,
} from "./messages";

const threadRow = {
  id: "thread-1",
  shop_id: "shop-1",
  buyer_id: "buyer-1",
  vendor_id: "vendor-1",
  kind: "buyer_vendor",
  last_message_preview: "Hi there",
  last_message_type: "text",
  last_message_sender_id: "vendor-1",
  last_message_at: "2026-05-13T10:00:00.000Z",
  created_at: "2026-05-13T09:00:00.000Z",
  updated_at: "2026-05-13T10:00:00.000Z",
  shops: {
    name: "StellieScent",
    logo_url: "shop.jpg",
  },
  buyer: {
    display_name: "Buyer",
    avatar_url: null,
  },
  vendor: {
    display_name: "Seller",
    avatar_url: "seller.jpg",
  },
  chat_thread_reads: [
    {
      participant_id: "buyer-1",
      last_read_at: "2026-05-13T09:30:00.000Z",
      last_read_message_id: "message-1",
    },
  ],
};

const messageRow = {
  id: "message-2",
  thread_id: "thread-1",
  sender_id: "vendor-1",
  body: "  Your order is ready  ",
  message_type: "text",
  attachment_url: null,
  attachment_path: null,
  attachment_name: null,
  attachment_mime: null,
  attachment_size_bytes: null,
  created_at: "2026-05-13T10:00:00.000Z",
};

describe("buyer message helpers", () => {
  it("maps thread rows with the current user's read marker", () => {
    const thread = mapBuyerChatThread(threadRow, "buyer-1");

    expect(thread).toMatchObject({
      id: "thread-1",
      shopName: "StellieScent",
      vendorDisplayName: "Seller",
      previewText: "Hi there",
      lastReadAt: "2026-05-13T09:30:00.000Z",
    });
    expect(isThreadUnread(thread, "buyer-1")).toBe(true);
  });

  it("does not mark a thread unread for the sender", () => {
    const thread = mapBuyerChatThread(
      {
        ...threadRow,
        last_message_sender_id: "buyer-1",
      },
      "buyer-1",
    );

    expect(isThreadUnread(thread, "buyer-1")).toBe(false);
  });

  it("maps messages and previews attachment-only messages", () => {
    const textMessage = mapBuyerChatMessage(messageRow);
    const attachmentMessage = mapBuyerChatMessage({
      ...messageRow,
      body: " ",
      message_type: "attachment",
      attachment_name: "invoice.pdf",
      attachment_path: "thread-1/invoice.pdf",
      attachment_mime: "application/pdf",
      attachment_size_bytes: 2048,
    });

    expect(textMessage.body).toBe("Your order is ready");
    expect(textMessage.isMine("buyer-1")).toBe(false);
    expect(getMessagePreview(attachmentMessage)).toBe("invoice.pdf");
  });

  it("counts unread messages after the read marker", () => {
    const thread = mapBuyerChatThread(threadRow, "buyer-1");
    const messages = [
      mapBuyerChatMessage({ ...messageRow, id: "old", created_at: "2026-05-13T09:15:00.000Z" }),
      mapBuyerChatMessage(messageRow),
      mapBuyerChatMessage({ ...messageRow, id: "mine", sender_id: "buyer-1" }),
    ];

    expect(getUnreadMessageCount(thread, messages, "buyer-1")).toBe(1);
  });
});
