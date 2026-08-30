import "server-only";

import { createAdminClient } from "@/lib/supabase/admin";

const PUBLIC_SHOP_ASSET_MARKER = "/storage/v1/object/public/shop-assets/";

function storagePathFromPublicShopAssetUrl(assetUrl: string) {
  try {
    const pathname = new URL(assetUrl).pathname;
    const markerIndex = pathname.indexOf(PUBLIC_SHOP_ASSET_MARKER);
    if (markerIndex < 0) return null;
    return decodeURIComponent(
      pathname.slice(markerIndex + PUBLIC_SHOP_ASSET_MARKER.length),
    );
  } catch {
    return null;
  }
}

export async function removeReplacedShopAsset(
  admin: ReturnType<typeof createAdminClient>,
  ownerId: string,
  previousUrl: string | null | undefined,
  nextUrl: string | null | undefined,
) {
  if (!previousUrl || previousUrl === nextUrl) return;

  const path = storagePathFromPublicShopAssetUrl(previousUrl);
  if (!path || !path.startsWith(`${ownerId}/`)) return;

  const { error } = await admin.storage.from("shop-assets").remove([path]);
  if (error) {
    console.error("[shop-assets] Unable to remove replaced file", error.message);
  }
}
