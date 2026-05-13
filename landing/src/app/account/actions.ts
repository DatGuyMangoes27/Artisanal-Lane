"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  normalizeSavedAddresses,
  serializeSavedAddresses,
  upsertSavedAddress,
} from "@/lib/marketplace/buyer-preferences";
import { createClient } from "@/lib/supabase/server";

async function requireUser(redirectTo: string) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect(`/login?redirect=${encodeURIComponent(redirectTo)}`);
  }

  return { supabase, user };
}

export async function toggleFavouriteProduct(formData: FormData) {
  const productId = String(formData.get("productId") ?? "").trim();
  const redirectTo = String(formData.get("redirectTo") ?? "/account/favourites");
  const action = String(formData.get("action") ?? "add");
  const { supabase, user } = await requireUser(redirectTo);

  if (productId) {
    if (action === "remove") {
      await supabase
        .from("favourites")
        .delete()
        .eq("user_id", user.id)
        .eq("product_id", productId);
    } else {
      await supabase.from("favourites").upsert({
        user_id: user.id,
        product_id: productId,
      });
    }
  }

  revalidatePath("/account");
  revalidatePath("/account/favourites");
  revalidatePath(redirectTo);
  redirect(redirectTo);
}

export async function saveAddress(formData: FormData) {
  const { supabase, user } = await requireUser("/account/addresses");
  const { data } = await supabase
    .from("profiles")
    .select("shipping_addresses")
    .eq("id", user.id)
    .single<{ shipping_addresses: unknown }>();

  const addresses = normalizeSavedAddresses(data?.shipping_addresses);
  const nextAddresses = upsertSavedAddress(addresses, {
    name: String(formData.get("name") ?? "").trim(),
    street: String(formData.get("street") ?? "").trim(),
    city: String(formData.get("city") ?? "").trim(),
    postalCode: String(formData.get("postalCode") ?? "").trim(),
    province: String(formData.get("province") ?? "").trim(),
    country: "South Africa",
    phone: String(formData.get("phone") ?? "").trim(),
    isDefault: formData.get("isDefault") === "on" || addresses.length === 0,
  });

  await supabase
    .from("profiles")
    .update({ shipping_addresses: serializeSavedAddresses(nextAddresses) })
    .eq("id", user.id);

  revalidatePath("/account/addresses");
  redirect("/account/addresses");
}
