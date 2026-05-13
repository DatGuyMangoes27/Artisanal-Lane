import "server-only";

import { createClient } from "@/lib/supabase/server";
import { getReviewSummary, mapProductReview, type ProductReview } from "./reviews";

const productReviewSelect = "*, profiles(display_name, avatar_url)";

export async function listProductReviews(productId: string): Promise<ProductReview[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("product_reviews")
    .select(productReviewSelect)
    .eq("product_id", productId)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load product reviews", { cause: error });
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map(mapProductReview);
}

export async function getProductReviewOverview(productId: string) {
  const reviews = await listProductReviews(productId);
  return {
    reviews,
    summary: getReviewSummary(reviews),
  };
}

export async function getLatestEligibleProductReviewContext(
  buyerId: string,
  productId: string,
) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("order_items")
    .select("id, order_id, orders!inner(id, buyer_id, status, created_at)")
    .eq("product_id", productId)
    .eq("orders.buyer_id", buyerId)
    .in("orders.status", ["delivered", "completed"])
    .order("created_at", { foreignTable: "orders", ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to check review eligibility", { cause: error });
  }

  const row = data as { id?: string; order_id?: string } | null;
  return row?.id && row.order_id
    ? { orderId: row.order_id, orderItemId: row.id }
    : null;
}
