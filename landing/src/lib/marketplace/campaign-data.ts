import { createAdminClient } from "@/lib/supabase/admin";
import {
  addCampaignProductImages,
  buildCampaignOffers,
  type CampaignCouponRow,
  type CampaignOffer,
  type CampaignProductImageRow,
} from "@/lib/marketplace/campaign-offers";

const campaignCouponSelect = `
  id,
  code,
  description,
  discount_type,
  discount_value,
  scope,
  minimum_subtotal,
  starts_at,
  ends_at,
  is_active,
  created_at,
  shops!inner(
    id,
    name,
    slug,
    logo_url,
    cover_image_url,
    location,
    is_active,
    is_offline
  )
`;

// This shop has a valid store coupon but is not participating in Stitch & Save.
const BOERSEEP_SHOP_ID = "db859a2d-c209-4672-a3b0-48b65de505b6";

export async function listCampaignOffers(): Promise<CampaignOffer[]> {
  const admin = createAdminClient();
  const now = new Date();
  const { data, error } = await admin
    .from("shop_coupons")
    .select(campaignCouponSelect)
    .eq("is_active", true)
    .eq("shops.is_active", true)
    .eq("shops.is_offline", false)
    .neq("shops.id", BOERSEEP_SHOP_ID)
    .or(`ends_at.is.null,ends_at.gt.${now.toISOString()}`)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[campaign] Failed to load homepage offers", error.message);
    return [];
  }

  const offers = buildCampaignOffers((data ?? []) as CampaignCouponRow[], now);
  if (offers.length === 0) return [];

  const { data: products, error: productError } = await admin
    .from("products")
    .select("shop_id, title, images, is_featured, created_at")
    .in("shop_id", offers.map((offer) => offer.shopId))
    .eq("is_published", true)
    .order("is_featured", { ascending: false })
    .order("created_at", { ascending: false });

  if (productError) {
    console.error("[campaign] Failed to load artisan product images", productError.message);
    return offers;
  }

  return addCampaignProductImages(offers, (products ?? []) as CampaignProductImageRow[]);
}
