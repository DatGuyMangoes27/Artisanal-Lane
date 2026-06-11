import {
  getSupabaseServiceRoleKey,
  getSupabaseUrl,
} from "@/lib/supabase/env";

export async function sendChatMessagePushNotifications(messageIds: string[]) {
  const ids = messageIds.map((id) => id.trim()).filter(Boolean);
  if (ids.length === 0) return;

  try {
    await fetch(`${getSupabaseUrl()}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${getSupabaseServiceRoleKey()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        type: "chat_message",
        messageIds: ids,
      }),
    });
  } catch (error) {
    console.error("Unable to send chat push notifications", error);
  }
}

export type AdminBroadcastAudience =
  | "user"
  | "all_vendors"
  | "all_buyers"
  | "subscribed_vendors"
  | "vendors_without_shop";

export type AdminBroadcastResult = {
  recipients: number;
  sent: number;
  failed: number;
};

export async function sendAdminBroadcastPushNotification({
  title,
  body,
  route,
  audience,
  userId,
}: {
  title: string;
  body: string;
  route?: string | null;
  audience: AdminBroadcastAudience;
  userId?: string | null;
}): Promise<AdminBroadcastResult> {
  const response = await fetch(
    `${getSupabaseUrl()}/functions/v1/admin-broadcast-push`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${getSupabaseServiceRoleKey()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        title,
        body,
        ...(route ? { route } : {}),
        audience,
        ...(userId ? { userId } : {}),
      }),
    },
  );

  const result = (await response.json().catch(() => ({}))) as {
    ok?: boolean;
    error?: string;
    recipients?: number;
    sent?: number;
    failed?: number;
  };

  if (!response.ok || result.ok !== true) {
    throw new Error(result.error || "Unable to send push notification.");
  }

  return {
    recipients: result.recipients ?? 0,
    sent: result.sent ?? 0,
    failed: result.failed ?? 0,
  };
}

export async function sendDisputeResolvedPushNotification({
  orderId,
  disputeId,
}: {
  orderId: string;
  disputeId: string;
}) {
  try {
    await fetch(`${getSupabaseUrl()}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${getSupabaseServiceRoleKey()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        type: "dispute_update",
        orderId,
        disputeId,
        event: "resolved",
      }),
    });
  } catch (error) {
    console.error("Unable to send dispute push notification", error);
  }
}
