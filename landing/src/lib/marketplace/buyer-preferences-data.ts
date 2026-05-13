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
  const { data, error } = await supabase
    .from("profiles")
    .select("shipping_addresses")
    .eq("id", userId)
    .single<{ shipping_addresses: unknown }>();

  if (error) {
    throw new Error("Failed to load saved addresses", { cause: error });
  }

  return normalizeSavedAddresses(data.shipping_addresses);
}
