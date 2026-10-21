import "server-only";

import { createClient } from "@/lib/supabase/server";

export type BuyerNotification = {
  id: string;
  title: string;
  body: string;
  type: string;
  eventKey: string;
  data: Record<string, unknown>;
  readAt: string | null;
  createdAt: string;
};

function toRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

export async function listBuyerNotifications(userId: string): Promise<BuyerNotification[]> {
  const supabase = await createClient();
  const query = (onlyVisible: boolean) => {
    const base = supabase
      .from("notifications")
      .select("id, title, body, notification_type, event_key, data, read_at, created_at")
      .eq("user_id", userId);
    // Notifications cleared in the app (dismissed_at set) stay cleared here.
    return (onlyVisible ? base.is("dismissed_at", null) : base)
      .order("created_at", { ascending: false })
      .limit(50);
  };

  let { data, error } = await query(true);
  if (error) {
    // Databases without the dismissed_at column yet.
    ({ data, error } = await query(false));
  }

  if (error) {
    throw new Error("Failed to load notifications", { cause: error });
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    id: String(row.id),
    title: String(row.title ?? "Notification"),
    body: String(row.body ?? ""),
    type: String(row.notification_type ?? "general"),
    eventKey: String(row.event_key ?? ""),
    data: toRecord(row.data),
    readAt: typeof row.read_at === "string" ? row.read_at : null,
    createdAt: String(row.created_at),
  }));
}
