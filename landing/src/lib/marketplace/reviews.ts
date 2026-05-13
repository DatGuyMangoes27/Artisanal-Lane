export type ProductReview = {
  id: string;
  productId: string;
  shopId: string;
  buyerId: string;
  orderId: string | null;
  orderItemId: string | null;
  rating: number;
  reviewText: string | null;
  createdAt: string;
  updatedAt: string;
  buyerDisplayName: string | null;
  buyerAvatarUrl: string | null;
};

type JsonRecord = Record<string, unknown>;

function toRecord(value: unknown): JsonRecord | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonRecord)
    : null;
}

function text(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function number(value: unknown, fallback = 0) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

export function mapProductReview(row: JsonRecord): ProductReview {
  const profile = toRecord(row.profiles);

  return {
    id: String(row.id),
    productId: String(row.product_id),
    shopId: String(row.shop_id),
    buyerId: String(row.buyer_id),
    orderId: text(row.order_id),
    orderItemId: text(row.order_item_id),
    rating: Math.trunc(number(row.rating)),
    reviewText: text(row.review_text),
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
    buyerDisplayName: text(profile?.display_name),
    buyerAvatarUrl: text(profile?.avatar_url),
  };
}

export function getReviewSummary(reviews: Array<Pick<ProductReview, "rating">>) {
  if (reviews.length === 0) {
    return { averageRating: 0, reviewCount: 0 };
  }

  const total = reviews.reduce((sum, review) => sum + review.rating, 0);
  return {
    averageRating: total / reviews.length,
    reviewCount: reviews.length,
  };
}

export function normalizeReviewRating(value: FormDataEntryValue | null) {
  const rating = Number(value);
  if (!Number.isFinite(rating)) {
    return 5;
  }

  return Math.min(5, Math.max(1, Math.trunc(rating)));
}

export function sanitizeReviewText(value: FormDataEntryValue | null) {
  const trimmed = String(value ?? "").trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function canReviewOrderStatus(status: string | null | undefined) {
  return status === "delivered" || status === "completed";
}
