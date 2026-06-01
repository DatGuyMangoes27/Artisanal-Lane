import "server-only";

import { createClient } from "@/lib/supabase/server";

export type ShopPost = {
  id: string;
  shopId: string;
  caption: string;
  mediaUrls: string[];
  createdAt: string;
};

export type ShopMarketEvent = {
  id: string;
  marketName: string;
  location: string;
  eventDate: string;
  timeLabel: string | null;
  notes: string | null;
};

export type ShopReviewSummary = {
  averageRating: number;
  reviewCount: number;
};

function toStringArray(value: unknown) {
  return Array.isArray(value) ? value.map(String).filter(Boolean) : [];
}

export async function listShopPosts(shopId: string, limit = 6): Promise<ShopPost[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("shop_posts")
    .select("id, shop_id, caption, media_urls, created_at")
    .eq("shop_id", shopId)
    .eq("is_published", true)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error("Failed to load shop posts", { cause: error });
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    id: String(row.id),
    shopId: String(row.shop_id),
    caption: String(row.caption ?? ""),
    mediaUrls: toStringArray(row.media_urls),
    createdAt: String(row.created_at),
  }));
}

export async function listShopMarketEvents(shopId: string, limit = 3): Promise<ShopMarketEvent[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("shop_market_events")
    .select("id, market_name, location, event_date, time_label, notes")
    .eq("shop_id", shopId)
    .eq("is_active", true)
    .gte("event_date", new Date().toISOString().slice(0, 10))
    .order("event_date", { ascending: true })
    .limit(limit);

  if (error) {
    throw new Error("Failed to load shop market events", { cause: error });
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    id: String(row.id),
    marketName: String(row.market_name ?? "Market"),
    location: String(row.location ?? ""),
    eventDate: String(row.event_date),
    timeLabel: typeof row.time_label === "string" ? row.time_label : null,
    notes: typeof row.notes === "string" ? row.notes : null,
  }));
}

export async function getShopReviewSummary(shopId: string): Promise<ShopReviewSummary> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("shop_reviews")
    .select("rating")
    .eq("shop_id", shopId);

  if (error) {
    throw new Error("Failed to load shop reviews", { cause: error });
  }

  const ratings = ((data ?? []) as Array<{ rating: number | string }>).map((row) =>
    Number(row.rating),
  ).filter(Number.isFinite);

  return {
    averageRating: ratings.length === 0
      ? 0
      : ratings.reduce((total, rating) => total + rating, 0) / ratings.length,
    reviewCount: ratings.length,
  };
}
