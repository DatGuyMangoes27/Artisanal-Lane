import { describe, expect, it } from "vitest";

import {
  canReviewOrderStatus,
  getReviewSummary,
  mapProductReview,
  normalizeReviewRating,
  sanitizeReviewText,
} from "./reviews";

describe("product review helpers", () => {
  it("maps product review rows with buyer profile details", () => {
    expect(
      mapProductReview({
        id: "review-1",
        product_id: "product-1",
        shop_id: "shop-1",
        buyer_id: "buyer-1",
        order_id: "order-1",
        order_item_id: "item-1",
        rating: 5,
        review_text: "Beautifully made.",
        created_at: "2026-01-01T00:00:00.000Z",
        updated_at: "2026-01-02T00:00:00.000Z",
        profiles: {
          display_name: "Ros",
          avatar_url: "https://example.com/avatar.jpg",
        },
      }),
    ).toEqual({
      id: "review-1",
      productId: "product-1",
      shopId: "shop-1",
      buyerId: "buyer-1",
      orderId: "order-1",
      orderItemId: "item-1",
      rating: 5,
      reviewText: "Beautifully made.",
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-02T00:00:00.000Z",
      buyerDisplayName: "Ros",
      buyerAvatarUrl: "https://example.com/avatar.jpg",
    });
  });

  it("summarizes ratings", () => {
    expect(getReviewSummary([{ rating: 5 }, { rating: 4 }, { rating: 3 }])).toEqual({
      averageRating: 4,
      reviewCount: 3,
    });
  });

  it("normalizes submitted rating and review text", () => {
    expect(normalizeReviewRating("7")).toBe(5);
    expect(normalizeReviewRating("0")).toBe(1);
    expect(sanitizeReviewText("  Lovely texture.  ")).toBe("Lovely texture.");
    expect(sanitizeReviewText("   ")).toBeNull();
  });

  it("allows reviews only for completed delivery states", () => {
    expect(canReviewOrderStatus("delivered")).toBe(true);
    expect(canReviewOrderStatus("completed")).toBe(true);
    expect(canReviewOrderStatus("paid")).toBe(false);
  });
});
