import { describe, expect, it } from "vitest";

import {
  addCampaignProductImages,
  buildCampaignOffers,
  type CampaignCouponRow,
} from "./campaign-offers";

function row(overrides: Partial<CampaignCouponRow> = {}): CampaignCouponRow {
  return {
    id: "coupon-1",
    code: "WELCOME10",
    description: "Launch promotion",
    discount_type: "percentage",
    discount_value: 10,
    scope: "store",
    minimum_subtotal: 50,
    starts_at: "2026-08-01T00:00:00Z",
    ends_at: "2026-09-01T00:00:00Z",
    is_active: true,
    created_at: "2026-08-01T00:00:00Z",
    shops: {
      id: "shop-1",
      name: "Cosmos Crochet",
      slug: "cosmos-crochet",
      logo_url: null,
      cover_image_url: "https://example.com/cover.jpg",
      location: "Mooinooi, NW",
      is_active: true,
      is_offline: false,
    },
    ...overrides,
  };
}

describe("buildCampaignOffers", () => {
  const now = new Date("2026-08-06T12:00:00Z");

  it("maps a currently valid coupon into a campaign shop offer", () => {
    expect(buildCampaignOffers([row()], now)).toEqual([
      expect.objectContaining({
        shopName: "Cosmos Crochet",
        shopSlug: "cosmos-crochet",
        code: "WELCOME10",
        discountType: "percentage",
        discountValue: 10,
        startsAt: "2026-08-01T00:00:00Z",
      }),
    ]);
  });

  it("includes upcoming offers and excludes inactive, expired, suspended, and offline offers", () => {
    const future = row({
      id: "future",
      starts_at: "2026-08-07T00:00:00Z",
      shops: { id: "shop-future", name: "Future", is_active: true, is_offline: false },
    });
    const expired = row({ id: "expired", ends_at: "2026-08-06T11:59:59Z" });
    const inactive = row({ id: "inactive", is_active: false });
    const suspended = row({
      id: "suspended",
      shops: { id: "shop-2", name: "Suspended", is_active: false, is_offline: false },
    });
    const offline = row({
      id: "offline",
      shops: { id: "shop-3", name: "Offline", is_active: true, is_offline: true },
    });

    expect(buildCampaignOffers([future, expired, inactive, suspended, offline], now)).toEqual([
      expect.objectContaining({ couponId: "future", startsAt: "2026-08-07T00:00:00Z" }),
    ]);
  });

  it("orders active offers before upcoming offers and upcoming offers by start time", () => {
    const later = row({
      id: "later",
      starts_at: "2026-08-08T00:00:00Z",
      shops: { id: "shop-later", name: "Later", is_active: true, is_offline: false },
    });
    const active = row({
      id: "active",
      shops: { id: "shop-active", name: "Active", is_active: true, is_offline: false },
    });
    const sooner = row({
      id: "sooner",
      starts_at: "2026-08-07T00:00:00Z",
      shops: { id: "shop-sooner", name: "Sooner", is_active: true, is_offline: false },
    });

    expect(buildCampaignOffers([later, active, sooner], now).map((offer) => offer.couponId)).toEqual([
      "active",
      "sooner",
      "later",
    ]);
  });

  it("keeps only the first active coupon per shop", () => {
    const newer = row({ id: "newer", code: "NEW20" });
    const older = row({ id: "older", code: "OLD10" });

    expect(buildCampaignOffers([newer, older], now)).toHaveLength(1);
    expect(buildCampaignOffers([newer, older], now)[0].code).toBe("NEW20");
  });

  it("adds a real product image from the matching artisan shop", () => {
    const offers = buildCampaignOffers([row()], now);
    const enriched = addCampaignProductImages(offers, [
      {
        shop_id: "shop-1",
        title: "Crochet Bee",
        images: ["https://example.com/bee.jpg"],
      },
    ]);

    expect(enriched[0]).toEqual(
      expect.objectContaining({
        productImageUrl: "https://example.com/bee.jpg",
        productTitle: "Crochet Bee",
      }),
    );
  });

  it("ignores empty product images and preserves the campaign fallback", () => {
    const offers = buildCampaignOffers([row()], now);
    const enriched = addCampaignProductImages(offers, [
      { shop_id: "shop-1", title: "No photo", images: [] },
    ]);

    expect(enriched[0].productImageUrl).toBeNull();
    expect(enriched[0].productTitle).toBeNull();
  });
});
