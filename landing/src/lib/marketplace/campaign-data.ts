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

export async function listActiveCampaignOffers(): Promise<CampaignOffer[]> {
  const admin = createAdminClient();
  const now = new Date();
  const nowIso = now.toISOString();
  const { data, error } = await admin
    .from("shop_coupons")
    .select(campaignCouponSelect)
    .eq("is_active", true)
    .eq("shops.is_active", true)
    .eq("shops.is_offline", false)
    .or(`starts_at.is.null,starts_at.lte.${nowIso}`)
    .or(`ends_at.is.null,ends_at.gt.${nowIso}`)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("[campaign] Failed to load active homepage offers", error.message);
    return [];
  }

  return buildCampaignOffers((data ?? []) as CampaignCouponRow[], now);
}
