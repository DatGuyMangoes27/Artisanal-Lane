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
