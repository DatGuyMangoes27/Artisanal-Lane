import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import {
  buildChatMessagePush,
  buildDisputePush,
  buildOrderPush,
  buildStoredNotification,
  type ChatThreadPushRow,
  type DisputePushEvent,
  getFirebaseAccessToken,
  type OrderPushEvent,
  parseFirebaseServiceAccount,
  type PushPayload,
  recipientForChatMessage,
  sendFirebasePush,
} from "../_shared/push.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type AdminClient = ReturnType<typeof createClient<any, any, any>>;

Deno.serve(async (request) => {
  try {
    const body = await request.json();
    const type = String(body.type ?? "");
    const messageIds = normalizeMessageIds(body.messageId ?? body.messageIds);
    const orderId = typeof body.orderId === "string" ? body.orderId.trim() : "";
    const disputeId = typeof body.disputeId === "string"
      ? body.disputeId.trim()
      : "";
    const event = typeof body.event === "string" ? body.event.trim() : "";
    const reminderKey = typeof body.reminderKey === "string"
      ? body.reminderKey.trim()
      : "";

    if (
      (type === "chat_message" && messageIds.length === 0) ||
      (type === "order_update" && (!orderId || !isOrderPushEvent(event))) ||
      (type === "dispute_update" &&
        (!orderId || !disputeId || !isDisputePushEvent(event))) ||
      !["chat_message", "order_update", "dispute_update"].includes(type)
    ) {
      return jsonResponse({ error: "Unsupported push notification request." }, {
        status: 400,
      });
    }

    const jwt = getBearerToken(request);
    const isServiceRequest = jwt === supabaseServiceRoleKey ||
      getJwtRole(jwt) === "service_role";
    const callerId = isServiceRequest ? null : await getCallerId(jwt);

    if (!isServiceRequest && callerId == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const firebaseServiceAccountRaw = Deno.env.get(
      "FIREBASE_SERVICE_ACCOUNT_JSON",
    );
    if (!firebaseServiceAccountRaw) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON secret.");
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const firebaseServiceAccount = parseFirebaseServiceAccount(
      firebaseServiceAccountRaw,
    );
    const accessToken = await getFirebaseAccessToken(firebaseServiceAccount);
    let sent = 0;
    let skipped = 0;
    const failures: Array<{ tokenId: string; status: number }> = [];

    if (type === "chat_message") {
      for (const messageId of messageIds) {
        const result = await sendChatMessageNotification({
          admin,
          accessToken,
          projectId: firebaseServiceAccount.project_id,
          messageId,
          callerId,
          isServiceRequest,
        });
        sent += result.sent;
        skipped += result.skipped;
        failures.push(...result.failures);
      }
    }

    if (type === "order_update" && isOrderPushEvent(event)) {
      const result = await sendOrderUpdateNotification({
        admin,
        accessToken,
        projectId: firebaseServiceAccount.project_id,
        orderId,
        event,
        reminderKey,
      });
      sent += result.sent;
      skipped += result.skipped;
      failures.push(...result.failures);
    }

    if (
      type === "dispute_update" && isDisputePushEvent(event) &&
      disputeId.length > 0
    ) {
      const result = await sendDisputeUpdateNotification({
        admin,
        accessToken,
        projectId: firebaseServiceAccount.project_id,
        orderId,
        disputeId,
        event,
      });
      sent += result.sent;
      skipped += result.skipped;
      failures.push(...result.failures);
    }

    return jsonResponse({ ok: true, sent, skipped, failures });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Unable to send push notification.",
      },
      { status: 500 },
    );
  }
});

async function sendChatMessageNotification({
  admin,
  accessToken,
  projectId,
  messageId,
  callerId,
  isServiceRequest,
}: {
  admin: AdminClient;
  accessToken: string;
  projectId: string;
  messageId: string;
  callerId: string | null;
  isServiceRequest: boolean;
}) {
  const failures: Array<{ tokenId: string; status: number }> = [];
  let sent = 0;
  let skipped = 0;

  // The chat_threads embed must name the FK: chat_threads also references
  // chat_messages via admin_last_read_message_id, so an un-hinted embed is
  // ambiguous and PostgREST rejects it (PGRST201).
  const { data: message, error: messageError } = await admin
    .from("chat_messages")
    .select(
      "id, sender_id, body, message_type, chat_threads!chat_messages_thread_id_fkey!inner(id, buyer_id, vendor_id, kind, shops(name))",
    )
    .eq("id", messageId)
    .single();

  if (messageError != null || message == null) {
    console.error(
      `chat push skipped: unable to load message ${messageId}: ${messageError?.message ?? "not found"}`,
    );
    return { sent, skipped: skipped + 1, failures };
  }

  if (!isServiceRequest && message.sender_id !== callerId) {
    console.error(
      `chat push skipped: caller ${callerId} is not the sender of message ${messageId}`,
    );
    return { sent, skipped: skipped + 1, failures };
  }

  const thread = message.chat_threads as unknown as ChatThreadPushRow;
  const recipient = recipientForChatMessage(
    thread,
    message.sender_id as string,
  );
  if (recipient == null) {
    console.error(
      `chat push skipped: no recipient resolved for message ${messageId} in thread ${thread.id}`,
    );
    return { sent, skipped: skipped + 1, failures };
  }

  const { data: senderProfile } = await admin
    .from("profiles")
    .select("display_name, role")
    .eq("id", message.sender_id)
    .maybeSingle();

  const payload = buildChatMessagePush({
    threadId: thread.id,
    messageId: message.id as string,
    recipientRole: recipient.role,
    senderLabel: chatSenderLabel({
      senderId: message.sender_id as string,
      senderProfile: senderProfile as {
        display_name?: string | null;
        role?: string | null;
      } | null,
      thread,
    }),
    body: message.body as string | null,
    messageType: message.message_type as string | null,
  });
  await storeNotification(admin, recipient.userId, payload);

  const { data: tokens } = await admin
    .from("user_push_tokens")
    .select("id, token")
    .eq("user_id", recipient.userId)
    .is("revoked_at", null);

  if (!tokens || tokens.length === 0) {
    return { sent, skipped: skipped + 1, failures };
  }

  const sendResult = await sendPayloadToTokens({
    admin,
    accessToken,
    projectId,
    tokens,
    payload,
  });

  return {
    sent: sent + sendResult.sent,
    skipped,
    failures: [...failures, ...sendResult.failures],
  };
}

async function sendOrderUpdateNotification({
  admin,
  accessToken,
  projectId,
  orderId,
  event,
  reminderKey,
}: {
  admin: AdminClient;
  accessToken: string;
  projectId: string;
  orderId: string;
  event: OrderPushEvent;
  reminderKey?: string;
}) {
  const { data: order } = await admin
    .from("orders")
    .select("id, buyer_id, tracking_number, shops(name, vendor_id)")
    .eq("id", orderId)
    .single();

  if (!order) return { sent: 0, skipped: 1, failures: [] };

  const shop = order.shops as {
    name?: string | null;
    vendor_id?: string | null;
  } | null;
  const recipients = orderRecipientsForEvent({
    event,
    buyerId: order.buyer_id as string,
    vendorId: shop?.vendor_id ?? null,
  });

  return await sendRecipientPayloads({
    admin,
    accessToken,
    projectId,
    recipients,
    payloadForRecipient: (recipientRole) =>
      buildOrderPush({
        event,
        orderId: order.id as string,
        recipientRole,
        shopName: shop?.name,
        trackingNumber: order.tracking_number as string | null,
        reminderKey,
      }),
  });
}

async function sendDisputeUpdateNotification({
  admin,
  accessToken,
  projectId,
  orderId,
  disputeId,
  event,
}: {
  admin: AdminClient;
  accessToken: string;
  projectId: string;
  orderId: string;
  disputeId: string;
  event: DisputePushEvent;
}) {
  const { data: order } = await admin
    .from("orders")
    .select("id, buyer_id, shops(name, vendor_id)")
    .eq("id", orderId)
    .single();

  if (!order) return { sent: 0, skipped: 1, failures: [] };

  const shop = order.shops as {
    name?: string | null;
    vendor_id?: string | null;
  } | null;
  const recipients = [
    { userId: order.buyer_id as string, role: "buyer" as const },
    ...(shop?.vendor_id
      ? [{ userId: shop.vendor_id, role: "vendor" as const }]
      : []),
  ];

  return await sendRecipientPayloads({
    admin,
    accessToken,
    projectId,
    recipients,
    payloadForRecipient: (recipientRole) =>
      buildDisputePush({
        event,
        orderId: order.id as string,
        disputeId,
        recipientRole,
        shopName: shop?.name,
      }),
  });
}

async function sendRecipientPayloads({
  admin,
  accessToken,
  projectId,
  recipients,
  payloadForRecipient,
}: {
  admin: AdminClient;
  accessToken: string;
  projectId: string;
  recipients: Array<{ userId: string; role: "buyer" | "vendor" }>;
  payloadForRecipient: (
    role: "buyer" | "vendor",
  ) => PushPayload;
}) {
  let sent = 0;
  let skipped = 0;
  const failures: Array<{ tokenId: string; status: number }> = [];

  for (const recipient of recipients) {
    const payload = payloadForRecipient(recipient.role);
    await storeNotification(admin, recipient.userId, payload);

    const { data: tokens } = await admin
      .from("user_push_tokens")
      .select("id, token")
      .eq("user_id", recipient.userId)
      .is("revoked_at", null);

    if (!tokens || tokens.length === 0) {
      skipped += 1;
      continue;
    }

    const result = await sendPayloadToTokens({
      admin,
      accessToken,
      projectId,
      tokens,
      payload,
    });
    sent += result.sent;
    failures.push(...result.failures);
  }

  return { sent, skipped, failures };
}

async function sendPayloadToTokens({
  admin,
  accessToken,
  projectId,
  tokens,
  payload,
}: {
  admin: AdminClient;
  accessToken: string;
  projectId: string;
  tokens: Array<{ id: unknown; token: unknown }>;
  payload: PushPayload;
}) {
  let sent = 0;
  const failures: Array<{ tokenId: string; status: number }> = [];

  for (const tokenRow of tokens) {
    const result = await sendFirebasePush({
      accessToken,
      projectId,
      token: tokenRow.token as string,
      payload,
    });

    if (result.ok) {
      sent += 1;
    } else {
      failures.push({
        tokenId: tokenRow.id as string,
        status: result.status,
      });
      if (result.status === 404 || result.status === 400) {
        await admin
          .from("user_push_tokens")
          .update({ revoked_at: new Date().toISOString() })
          .eq("id", tokenRow.id);
      }
    }
  }

  return { sent, failures };
}

async function storeNotification(
  admin: AdminClient,
  userId: string,
  payload: PushPayload,
) {
  const notification = buildStoredNotification(userId, payload);
  const { error } = await admin
    .from("notifications")
    .upsert(notification, {
      onConflict: "user_id,event_key",
      ignoreDuplicates: true,
    });

  if (error != null) {
    console.error("Unable to store notification", error.message);
  }
}

function normalizeMessageIds(input: unknown) {
  if (Array.isArray(input)) {
    return input
      .map((value) => String(value ?? "").trim())
      .filter((value) => value.length > 0);
  }

  const value = String(input ?? "").trim();
  return value.length > 0 ? [value] : [];
}

function chatSenderLabel({
  senderId,
  senderProfile,
  thread,
}: {
  senderId: string;
  senderProfile: { display_name?: string | null; role?: string | null } | null;
  thread: ChatThreadPushRow;
}) {
  if (senderProfile?.role === "admin" || thread.kind === "admin_vendor") {
    if (senderId === thread.buyer_id) return "Artisan Lane Admin";
  }

  // Applicant threads: the admin sits on the vendor side.
  if (thread.kind === "admin_applicant" && senderId === thread.vendor_id) {
    return "Artisan Lane Admin";
  }

  const displayName = senderProfile?.display_name?.trim();
  if (displayName) return displayName;

  if (senderId === thread.vendor_id) {
    return thread.shops?.name?.trim() || "the seller";
  }

  return "Artisan Lane";
}

function isOrderPushEvent(event: string): event is OrderPushEvent {
  return ["paid", "shipped", "receipt_reminder", "completed", "cancelled"]
    .includes(event);
}

function isDisputePushEvent(event: string): event is DisputePushEvent {
  return ["opened", "resolved"].includes(event);
}

function getJwtRole(jwt: string) {
  try {
    const payload = jwt.split(".")[1];
    if (!payload) return null;
    const decoded = JSON.parse(atob(base64UrlToBase64(payload))) as {
      role?: string;
    };
    return decoded.role ?? null;
  } catch (_) {
    return null;
  }
}

function base64UrlToBase64(value: string) {
  const padded = value.padEnd(value.length + (4 - value.length % 4) % 4, "=");
  return padded.replace(/-/g, "+").replace(/_/g, "/");
}

function orderRecipientsForEvent({
  event,
  buyerId,
  vendorId,
}: {
  event: OrderPushEvent;
  buyerId: string;
  vendorId: string | null;
}) {
  const recipients: Array<{ userId: string; role: "buyer" | "vendor" }> = [];

  if (event === "paid") {
    recipients.push({ userId: buyerId, role: "buyer" });
    if (vendorId != null) {
      recipients.push({ userId: vendorId, role: "vendor" });
    }
    return recipients;
  }

  if (event === "completed") {
    recipients.push({ userId: buyerId, role: "buyer" });
    if (vendorId != null) {
      recipients.push({ userId: vendorId, role: "vendor" });
    }
    return recipients;
  }

  if (event === "cancelled") {
    recipients.push({ userId: buyerId, role: "buyer" });
    if (vendorId != null) {
      recipients.push({ userId: vendorId, role: "vendor" });
    }
    return recipients;
  }

  recipients.push({ userId: buyerId, role: "buyer" });
  return recipients;
}

async function getCallerId(jwt: string) {
  const client = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const {
    data: { user },
  } = await client.auth.getUser();

  return user?.id ?? null;
}
