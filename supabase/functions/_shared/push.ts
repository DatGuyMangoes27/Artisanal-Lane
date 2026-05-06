export type ChatThreadPushRow = {
  id: string;
  buyer_id: string;
  vendor_id: string;
  kind?: string | null;
  shops?: { name?: string | null } | null;
};

type ChatRecipient = {
  userId: string;
  role: "buyer" | "vendor";
};

export type PushRecipientRole = "buyer" | "vendor";
export type OrderPushEvent = "paid" | "shipped" | "completed" | "cancelled";
export type DisputePushEvent = "opened" | "resolved";

export type PushPayload = {
  title: string;
  body: string;
  data: Record<string, string>;
};

export function recipientForChatMessage(
  thread: ChatThreadPushRow,
  senderId: string,
): ChatRecipient | null {
  if (thread.kind === "admin_vendor") {
    if (senderId === thread.vendor_id) {
      return { userId: thread.buyer_id, role: "buyer" };
    }

    return { userId: thread.vendor_id, role: "vendor" };
  }

  if (senderId === thread.buyer_id) {
    return { userId: thread.vendor_id, role: "vendor" };
  }

  if (senderId === thread.vendor_id) {
    return { userId: thread.buyer_id, role: "buyer" };
  }

  return null;
}

export function buildChatMessagePush({
  threadId,
  messageId,
  recipientRole,
  senderLabel,
  body,
  messageType,
}: {
  threadId: string;
  messageId: string;
  recipientRole: "buyer" | "vendor";
  senderLabel?: string | null;
  body?: string | null;
  messageType?: string | null;
}): PushPayload {
  const sender = senderLabel?.trim() || "Artisan Lane";
  const trimmedBody = body?.trim();
  const fallback = messageType === "text"
    ? "Sent a message"
    : "Sent an attachment";

  return {
    title: `New message from ${sender}`,
    body: trimmedBody && trimmedBody.length > 0 ? trimmedBody : fallback,
    data: {
      type: "chat_message",
      thread_id: threadId,
      message_id: messageId,
      recipient_role: recipientRole,
    },
  };
}

export function buildOrderPush({
  event,
  orderId,
  recipientRole,
  shopName,
  trackingNumber,
}: {
  event: OrderPushEvent;
  orderId: string;
  recipientRole: PushRecipientRole;
  shopName?: string | null;
  trackingNumber?: string | null;
}): PushPayload {
  const storeName = shopName?.trim() || "Artisan Lane";
  const copy = orderPushCopy({
    event,
    recipientRole,
    shopName: storeName,
    trackingNumber: trackingNumber?.trim() || null,
  });

  return {
    title: copy.title,
    body: copy.body,
    data: {
      type: "order_update",
      order_id: orderId,
      event,
      recipient_role: recipientRole,
    },
  };
}

export function buildDisputePush({
  event,
  orderId,
  disputeId,
  recipientRole,
  shopName,
}: {
  event: DisputePushEvent;
  orderId: string;
  disputeId: string;
  recipientRole: PushRecipientRole;
  shopName?: string | null;
}): PushPayload {
  const storeName = shopName?.trim() || "Artisan Lane";
  const title = event === "opened" ? "Dispute opened" : "Dispute resolved";
  const body = disputePushBody({ event, recipientRole, shopName: storeName });

  return {
    title,
    body,
    data: {
      type: "dispute_update",
      order_id: orderId,
      dispute_id: disputeId,
      event,
      recipient_role: recipientRole,
    },
  };
}

export async function sendInternalPushRequest({
  supabaseUrl,
  serviceRoleKey,
  body,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  body: Record<string, unknown>;
}) {
  try {
    await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    console.error("Unable to send push notification", error);
  }
}

function orderPushCopy({
  event,
  recipientRole,
  shopName,
  trackingNumber,
}: {
  event: OrderPushEvent;
  recipientRole: PushRecipientRole;
  shopName: string;
  trackingNumber?: string | null;
}) {
  if (event === "paid" && recipientRole === "vendor") {
    return {
      title: "New order received",
      body: `You have a new paid order for ${shopName}.`,
    };
  }

  if (event === "paid") {
    return {
      title: "Order confirmed",
      body: `Your order from ${shopName} is confirmed.`,
    };
  }

  if (event === "shipped") {
    return {
      title: "Order shipped",
      body: trackingNumber
        ? `${shopName} shipped your order. Tracking: ${trackingNumber}`
        : `${shopName} shipped your order.`,
    };
  }

  if (event === "completed" && recipientRole === "vendor") {
    return {
      title: "Order completed",
      body: `An order for ${shopName} was completed and funds were released.`,
    };
  }

  if (event === "completed") {
    return {
      title: "Order completed",
      body: `Your order from ${shopName} is complete.`,
    };
  }

  if (recipientRole === "vendor") {
    return {
      title: "Order cancelled",
      body: `An order for ${shopName} was cancelled or refunded.`,
    };
  }

  return {
    title: "Order cancelled",
    body: `Your order from ${shopName} was cancelled or refunded.`,
  };
}

function disputePushBody({
  event,
  recipientRole,
  shopName,
}: {
  event: DisputePushEvent;
  recipientRole: PushRecipientRole;
  shopName: string;
}) {
  if (event === "opened" && recipientRole === "vendor") {
    return `A dispute was opened for an order from ${shopName}.`;
  }

  if (event === "opened") {
    return `Your dispute for an order from ${shopName} was opened.`;
  }

  if (recipientRole === "vendor") {
    return `A dispute for an order from ${shopName} was resolved.`;
  }

  return `Your dispute for an order from ${shopName} was resolved.`;
}

export type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

export function parseFirebaseServiceAccount(
  raw: string,
): FirebaseServiceAccount {
  const parsed = JSON.parse(raw) as Partial<FirebaseServiceAccount>;
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error("Firebase service account is missing required fields.");
  }

  return {
    project_id: parsed.project_id,
    client_email: parsed.client_email,
    private_key: parsed.private_key.replace(/\\n/g, "\n"),
  };
}

export async function getFirebaseAccessToken(
  serviceAccount: FirebaseServiceAccount,
  now = Math.floor(Date.now() / 1000),
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsignedJwt = `${base64UrlEncodeJson(header)}.${
    base64UrlEncodeJson(claimSet)
  }`;
  const signature = await signRs256(unsignedJwt, serviceAccount.private_key);
  const assertion = `${unsignedJwt}.${signature}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const body = await response.json();
  if (!response.ok || typeof body.access_token !== "string") {
    throw new Error("Unable to authorize with Firebase Cloud Messaging.");
  }

  return body.access_token;
}

export async function sendFirebasePush({
  accessToken,
  projectId,
  token,
  payload,
}: {
  accessToken: string;
  projectId: string;
  token: string;
  payload: PushPayload;
}) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data,
          android: {
            priority: "HIGH",
            notification: {
              icon: "ic_notification",
              color: "#8B1E13",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        },
      }),
    },
  );

  const body = await response.json().catch(() => ({}));
  return { ok: response.ok, status: response.status, body };
}

function base64UrlEncodeJson(value: Record<string, unknown>) {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlEncode(bytes: Uint8Array) {
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

async function signRs256(payload: string, privateKey: string) {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKey),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(payload),
  );

  return base64UrlEncode(new Uint8Array(signature));
}

function pemToArrayBuffer(pem: string) {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}
