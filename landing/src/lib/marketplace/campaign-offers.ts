export type CampaignOffer = {
  couponId: string;
  shopId: string;
  shopName: string;
  shopSlug: string;
  shopLogoUrl: string | null;
  shopCoverImageUrl: string | null;
  shopLocation: string | null;
  code: string;
  description: string | null;
  discountType: "percentage" | "fixed";
  discountValue: number;
  scope: "store" | "products";
  minimumSubtotal: number;
  endsAt: string | null;
};

export type CampaignCouponRow = {
  id: unknown;
  code: unknown;
  description: unknown;
  discount_type: unknown;
  discount_value: unknown;
  scope: unknown;
  minimum_subtotal: unknown;
  starts_at: unknown;
  ends_at: unknown;
  is_active: unknown;
  created_at: unknown;
  shops: unknown;
};

type CampaignShopRow = {
  id?: unknown;
  name?: unknown;
  slug?: unknown;
  logo_url?: unknown;
  cover_image_url?: unknown;
  location?: unknown;
  is_active?: unknown;
  is_offline?: unknown;
};

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function nullableText(value: unknown): string | null {
  const valueAsText = text(value);
  return valueAsText || null;
}

function asShop(value: unknown): CampaignShopRow | null {
  if (Array.isArray(value)) {
    return (value[0] as CampaignShopRow | undefined) ?? null;
  }
  return value && typeof value === "object" ? (value as CampaignShopRow) : null;
}

export function buildCampaignOffers(
  rows: CampaignCouponRow[],
  now = new Date(),
): CampaignOffer[] {
  const shopIds = new Set<string>();
  const nowMs = now.getTime();

  return rows.flatMap((row) => {
    const shop = asShop(row.shops);
    const shopId = text(shop?.id);
    const couponId = text(row.id);
    const code = text(row.code);
    const shopName = text(shop?.name);
    const startsAt = nullableText(row.starts_at);
    const endsAt = nullableText(row.ends_at);
    const startsAtMs = startsAt ? Date.parse(startsAt) : null;
    const endsAtMs = endsAt ? Date.parse(endsAt) : null;

    if (
      row.is_active !== true ||
      shop?.is_active !== true ||
      shop?.is_offline === true ||
      !shopId ||
      !couponId ||
      !code ||
      !shopName ||
      (startsAtMs !== null && Number.isFinite(startsAtMs) && startsAtMs > nowMs) ||
      (endsAtMs !== null && Number.isFinite(endsAtMs) && endsAtMs <= nowMs) ||
      shopIds.has(shopId)
    ) {
      return [];
    }

    shopIds.add(shopId);
    return [
      {
        couponId,
        shopId,
        shopName,
        shopSlug: text(shop.slug) || shopId,
        shopLogoUrl: nullableText(shop.logo_url),
        shopCoverImageUrl: nullableText(shop.cover_image_url),
        shopLocation: nullableText(shop.location),
        code,
        description: nullableText(row.description),
        discountType: row.discount_type === "fixed" ? "fixed" : "percentage",
        discountValue: Number(row.discount_value ?? 0),
        scope: row.scope === "products" ? "products" : "store",
        minimumSubtotal: Number(row.minimum_subtotal ?? 0),
        endsAt,
      },
    ];
  });
}
