import { createAdminClient } from "@/lib/supabase/admin";
import {
  buildCampaignOffers,
  type CampaignCouponRow,
  type CampaignOffer,
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

  return buildCampaignOffers((data ?? []) as CampaignCouponRow[], now);
}
