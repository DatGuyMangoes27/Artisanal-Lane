import "server-only";

import { createClient } from "@/lib/supabase/server";
import type { BuyerDispute } from "./disputes";

type DisputeRow = {
  id: string;
  order_id: string;
  raised_by: string;
  reason: string;
  status: string;
  resolution: string | null;
  dispute_conversations?: { id: string } | Array<{ id: string }> | null;
};

export async function getActiveDisputeForOrder(orderId: string): Promise<BuyerDispute | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("disputes")
    .select("id, order_id, raised_by, reason, status, resolution, dispute_conversations(id)")
    .eq("order_id", orderId)
    .in("status", ["open", "investigating", "resolved"])
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load dispute", { cause: error });
  }

  if (!data) return null;
  const row = data as DisputeRow;
  const conversation = Array.isArray(row.dispute_conversations)
    ? row.dispute_conversations[0]
    : row.dispute_conversations;

  return {
    id: row.id,
    orderId: row.order_id,
    raisedBy: row.raised_by,
    reason: row.reason,
    status: row.status,
    resolution: row.resolution,
    conversationId: conversation?.id ?? null,
  };
}
