export type CampaignOffer = {
  couponId: string;
  shopId: string;
  shopName: string;
  shopSlug: string;
  shopLogoUrl: string | null;
  shopCoverImageUrl: string | null;
  shopLocation: string | null;
  productImageUrl: string | null;
  productTitle: string | null;
  code: string;
  description: string | null;
  discountType: "percentage" | "fixed";
  discountValue: number;
  scope: "store" | "products";
  minimumSubtotal: number;
  startsAt: string | null;
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

export type CampaignProductImageRow = {
  shop_id: string;
  title: string;
  images: unknown;
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

function firstImage(value: unknown): string | null {
  if (!Array.isArray(value)) return null;
  const image = value.find((item) => typeof item === "string" && item.trim() !== "");
  return typeof image === "string" ? image.trim() : null;
}

export function addCampaignProductImages(
  offers: CampaignOffer[],
  products: CampaignProductImageRow[],
): CampaignOffer[] {
  const productByShop = new Map<string, { imageUrl: string; title: string }>();
  for (const product of products) {
    if (productByShop.has(product.shop_id)) continue;
    const imageUrl = firstImage(product.images);
    if (!imageUrl) continue;
    productByShop.set(product.shop_id, { imageUrl, title: product.title });
  }

  return offers.map((offer) => {
    const product = productByShop.get(offer.shopId);
    return product
      ? { ...offer, productImageUrl: product.imageUrl, productTitle: product.title }
      : offer;
  });
}

export function buildCampaignOffers(
  rows: CampaignCouponRow[],
  now = new Date(),
): CampaignOffer[] {
  const shopIds = new Set<string>();
  const nowMs = now.getTime();
  const orderedRows = [...rows].sort((left, right) => {
    const leftStart = nullableText(left.starts_at);
    const rightStart = nullableText(right.starts_at);
    const leftStartMs = leftStart ? Date.parse(leftStart) : Number.NEGATIVE_INFINITY;
    const rightStartMs = rightStart ? Date.parse(rightStart) : Number.NEGATIVE_INFINITY;
    const leftUpcoming = Number.isFinite(leftStartMs) && leftStartMs > nowMs;
    const rightUpcoming = Number.isFinite(rightStartMs) && rightStartMs > nowMs;

    if (leftUpcoming !== rightUpcoming) return leftUpcoming ? 1 : -1;
    if (leftUpcoming && rightUpcoming) return leftStartMs - rightStartMs;
    return 0;
  });

  return orderedRows.flatMap((row) => {
    const shop = asShop(row.shops);
    const shopId = text(shop?.id);
    const couponId = text(row.id);
    const code = text(row.code);
    const shopName = text(shop?.name);
    const startsAt = nullableText(row.starts_at);
    const endsAt = nullableText(row.ends_at);
    const endsAtMs = endsAt ? Date.parse(endsAt) : null;

    if (
      row.is_active !== true ||
      shop?.is_active !== true ||
      shop?.is_offline === true ||
      !shopId ||
      !couponId ||
      !code ||
      !shopName ||
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
        productImageUrl: null,
        productTitle: null,
        code,
        description: nullableText(row.description),
        discountType: row.discount_type === "fixed" ? "fixed" : "percentage",
        discountValue: Number(row.discount_value ?? 0),
        scope: row.scope === "products" ? "products" : "store",
        minimumSubtotal: Number(row.minimum_subtotal ?? 0),
        startsAt,
        endsAt,
      },
    ];
  });
}
