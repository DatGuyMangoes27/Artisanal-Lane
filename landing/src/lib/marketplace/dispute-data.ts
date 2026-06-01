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
  created_at?: string;
  resolved_at?: string | null;
  orders?: { short_id?: string; status?: string } | Array<{ short_id?: string; status?: string }> | null;
  dispute_conversations?: { id: string } | Array<{ id: string }> | null;
};

function firstRelation<T>(value: T | T[] | null | undefined) {
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

function mapBuyerDispute(row: DisputeRow): BuyerDispute & {
  createdAt: string | null;
  resolvedAt: string | null;
  orderStatus: string | null;
} {
  const conversation = firstRelation(row.dispute_conversations);
  const order = firstRelation(row.orders);

  return {
    id: row.id,
    orderId: row.order_id,
    raisedBy: row.raised_by,
    reason: row.reason,
    status: row.status,
    resolution: row.resolution,
    conversationId: conversation?.id ?? null,
    createdAt: row.created_at ?? null,
    resolvedAt: row.resolved_at ?? null,
    orderStatus: order?.status ?? null,
  };
}

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
  return mapBuyerDispute(row);
}

export async function listBuyerDisputes(userId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("disputes")
    .select(
      "id, order_id, raised_by, reason, status, resolution, created_at, resolved_at, orders(status), dispute_conversations(id)",
    )
    .eq("raised_by", userId)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load buyer disputes", { cause: error });
  }

  return ((data ?? []) as DisputeRow[]).map(mapBuyerDispute);
}
