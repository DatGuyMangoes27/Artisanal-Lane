import "server-only";

import { createClient } from "@/lib/supabase/server";
import { getMarketplaceProductsByIds } from "./catalog";
import { normalizeSavedAddresses } from "./buyer-preferences";

export async function listFavouriteProductIds(userId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("favourites")
    .select("product_id")
    .eq("user_id", userId);

  if (error) {
    throw new Error("Failed to load favourites", { cause: error });
  }

  return (data ?? []).map((row: { product_id: string }) => row.product_id);
}

export async function listFavouriteProducts(userId: string) {
  const ids = await listFavouriteProductIds(userId);
  return getMarketplaceProductsByIds(ids);
}

export async function listSavedAddresses(userId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_my_profile");

  if (error) {
    throw new Error("Failed to load saved addresses", { cause: error });
  }

  const profile = data?.[0] as { shipping_addresses?: unknown } | undefined;

  return normalizeSavedAddresses(profile?.shipping_addresses ?? null);
}
