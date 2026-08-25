import "server-only";

import { createAdminClient } from "@/lib/supabase/admin";

const PUBLIC_PRODUCT_IMAGE_MARKER = "/storage/v1/object/public/product-images/";

function storagePathFromPublicUrl(imageUrl: string) {
  try {
    const pathname = new URL(imageUrl).pathname;
    const markerIndex = pathname.indexOf(PUBLIC_PRODUCT_IMAGE_MARKER);
    if (markerIndex < 0) return null;
    return decodeURIComponent(pathname.slice(markerIndex + PUBLIC_PRODUCT_IMAGE_MARKER.length));
  } catch {
    return null;
  }
}

export async function removeUnreferencedProductImages(
  admin: ReturnType<typeof createAdminClient>,
  imageUrls: string[],
) {
  const removablePaths: string[] = [];

  for (const imageUrl of [...new Set(imageUrls)]) {
    const path = storagePathFromPublicUrl(imageUrl);
    if (!path) continue;

    const [productReferences, variantReferences] = await Promise.all([
      admin.from("products").select("id", { count: "exact", head: true }).contains("images", [imageUrl]),
      admin.from("product_variants").select("id", { count: "exact", head: true }).contains("images", [imageUrl]),
    ]);

    // If reference verification fails, retain the file rather than risking a
    // broken image on another product or variant.
    if (productReferences.error || variantReferences.error) continue;
    if ((productReferences.count ?? 0) === 0 && (variantReferences.count ?? 0) === 0) {
      removablePaths.push(path);
    }
  }

  if (removablePaths.length > 0) {
    const { error } = await admin.storage.from("product-images").remove(removablePaths);
    if (error) {
      console.error("[product-images] Unable to remove unreferenced files", error.message);
    }
  }
}
