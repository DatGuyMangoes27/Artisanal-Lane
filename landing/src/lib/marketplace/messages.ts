export type BuyerChatThread = {
  id: string;
  shopId: string;
  buyerId: string;
  vendorId: string;
  kind: "buyer_vendor" | "admin_vendor" | "admin_applicant";
  lastMessagePreview: string | null;
  lastMessageType: string;
  lastMessageSenderId: string | null;
  lastMessageAt: string | null;
  createdAt: string;
  updatedAt: string;
  lastReadAt: string | null;
  lastReadMessageId: string | null;
  shopName: string;
  shopLogoUrl: string | null;
  buyerDisplayName: string | null;
  buyerAvatarUrl: string | null;
  vendorDisplayName: string | null;
  vendorAvatarUrl: string | null;
  previewText: string;
};

export type BuyerChatAttachment = {
  url: string | null;
  path: string | null;
  name: string | null;
  mime: string | null;
  sizeBytes: number | null;
};

export type BuyerChatMessage = {
  id: string;
  threadId: string;
  senderId: string;
  body: string | null;
  messageType: string;
  attachment: BuyerChatAttachment | null;
  createdAt: string;
  isMine: (userId: string) => boolean;
};

type JsonRecord = Record<string, unknown>;

function toRecord(value: unknown): JsonRecord | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonRecord)
    : null;
}

function toStringOrNull(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function toNumberOrNull(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

export function mapBuyerChatThread(row: JsonRecord, currentUserId: string): BuyerChatThread {
  const shop = toRecord(row.shops);
  const buyer = toRecord(row.buyer);
  const vendor = toRecord(row.vendor);
  const reads = Array.isArray(row.chat_thread_reads) ? row.chat_thread_reads : [];
  const currentRead = reads
    .map(toRecord)
    .find((read) => read?.participant_id === currentUserId);
  const lastMessageType = toStringOrNull(row.last_message_type) ?? "text";
  const lastMessagePreview = toStringOrNull(row.last_message_preview);

  const kind =
    row.kind === "admin_vendor"
      ? ("admin_vendor" as const)
      : row.kind === "admin_applicant"
        ? ("admin_applicant" as const)
        : ("buyer_vendor" as const);

  return {
    id: String(row.id),
    shopId: row.shop_id != null ? String(row.shop_id) : "",
    buyerId: String(row.buyer_id),
    vendorId: String(row.vendor_id),
    kind,
    lastMessagePreview,
    lastMessageType,
    lastMessageSenderId: toStringOrNull(row.last_message_sender_id),
    lastMessageAt: toStringOrNull(row.last_message_at),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
    lastReadAt: toStringOrNull(currentRead?.last_read_at),
    lastReadMessageId: toStringOrNull(currentRead?.last_read_message_id),
    shopName:
      toStringOrNull(shop?.name) ??
      (kind === "admin_applicant" ? "Artisan Lane" : "Artisan Lane seller"),
    shopLogoUrl: toStringOrNull(shop?.logo_url),
    buyerDisplayName: toStringOrNull(buyer?.display_name),
    buyerAvatarUrl: toStringOrNull(buyer?.avatar_url),
    vendorDisplayName: toStringOrNull(vendor?.display_name),
    vendorAvatarUrl: toStringOrNull(vendor?.avatar_url),
    previewText:
      lastMessagePreview ??
      (lastMessageType === "attachment" ? "Attachment" : "Start the conversation"),
  };
}

export function mapBuyerChatMessage(row: JsonRecord): BuyerChatMessage {
  const attachment = hasAttachment(row)
    ? {
        url: toStringOrNull(row.attachment_url),
        path: toStringOrNull(row.attachment_path),
        name: toStringOrNull(row.attachment_name),
        mime: toStringOrNull(row.attachment_mime),
        sizeBytes: toNumberOrNull(row.attachment_size_bytes),
      }
    : null;

  return {
    id: String(row.id),
    threadId: String(row.thread_id),
    senderId: String(row.sender_id),
    body: toStringOrNull(row.body),
    messageType: toStringOrNull(row.message_type) ?? "text",
    attachment,
    createdAt: String(row.created_at),
    isMine: (userId: string) => row.sender_id === userId,
  };
}

function hasAttachment(row: JsonRecord) {
  return (
    row.attachment_url != null ||
    row.attachment_path != null ||
    row.attachment_name != null
  );
}

export function getMessagePreview(message: BuyerChatMessage) {
  if (message.body) {
    return message.body;
  }

  return message.attachment?.name ?? "Attachment";
}

export function isThreadUnread(thread: BuyerChatThread, currentUserId: string) {
  if (!thread.lastMessageAt || thread.lastMessageSenderId === currentUserId) {
    return false;
  }

  if (!thread.lastReadAt) {
    return true;
  }

  return new Date(thread.lastMessageAt) > new Date(thread.lastReadAt);
}

export function getUnreadMessageCount(
  thread: BuyerChatThread,
  messages: BuyerChatMessage[],
  currentUserId: string,
) {
  if (!isThreadUnread(thread, currentUserId)) {
    return 0;
  }

  return messages.filter((message) => {
    if (message.senderId === currentUserId) {
      return false;
    }
    if (!thread.lastReadAt) {
      return true;
    }
    return new Date(message.createdAt) > new Date(thread.lastReadAt);
  }).length;
}
