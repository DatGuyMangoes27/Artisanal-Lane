"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import {
  normalizeSavedAddresses,
  serializeSavedAddresses,
  upsertSavedAddress,
} from "@/lib/marketplace/buyer-preferences";
import { getBuyerProfileUpdate, profileAvatarStoragePath } from "@/lib/marketplace/buyer-profile";
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

export async function toggleFavouriteProductInline(
  productId: string,
  shouldFavourite: boolean,
  redirectTo = "/",
) {
  const normalizedProductId = productId.trim();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return {
      ok: false,
      isFavourite: !shouldFavourite,
      redirectTo: `/login?redirect=${encodeURIComponent(redirectTo)}`,
    };
  }

  if (normalizedProductId) {
    if (shouldFavourite) {
      await supabase.from("favourites").upsert({
        user_id: user.id,
        product_id: normalizedProductId,
      });
    } else {
      await supabase
        .from("favourites")
        .delete()
        .eq("user_id", user.id)
        .eq("product_id", normalizedProductId);
    }
  }

  revalidatePath("/");
  revalidatePath("/shop");
  revalidatePath("/account");
  revalidatePath("/account/favourites");
  revalidatePath(redirectTo);

  return {
    ok: true,
    isFavourite: shouldFavourite,
    redirectTo: null,
  };
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

export async function updateBuyerProfile(formData: FormData) {
  const { supabase, user } = await requireUser("/account/profile");
  const update = getBuyerProfileUpdate(formData);

  await supabase
    .from("profiles")
    .update({
      ...update,
      updated_at: new Date().toISOString(),
    })
    .eq("id", user.id);

  revalidatePath("/account");
  revalidatePath("/account/profile");
  redirect("/account/profile");
}

export async function uploadBuyerAvatar(formData: FormData) {
  const { supabase, user } = await requireUser("/account/profile");
  const file = formData.get("avatar");

  if (!(file instanceof File) || file.size === 0) {
    redirect("/account/profile");
  }

  const path = profileAvatarStoragePath({
    userId: user.id,
    originalPath: file.name,
    timestampMillis: Date.now(),
  });
  const { error: uploadError } = await supabase.storage
    .from("avatars")
    .upload(path, file, { upsert: true });

  if (uploadError) {
    throw new Error(uploadError.message);
  }

  const { data } = supabase.storage.from("avatars").getPublicUrl(path);
  await supabase
    .from("profiles")
    .update({
      avatar_url: data.publicUrl,
      updated_at: new Date().toISOString(),
    })
    .eq("id", user.id);

  revalidatePath("/account");
  revalidatePath("/account/profile");
  redirect("/account/profile");
}

export async function markNotificationRead(formData: FormData) {
  const notificationId = String(formData.get("notificationId") ?? "").trim();
  const redirectTo = String(formData.get("redirectTo") ?? "/account/notifications");
  const { supabase, user } = await requireUser(redirectTo);

  if (notificationId) {
    await supabase
      .from("notifications")
      .update({ read_at: new Date().toISOString() })
      .eq("id", notificationId)
      .eq("user_id", user.id);
  }

  revalidatePath("/account");
  revalidatePath("/account/notifications");
  redirect(redirectTo);
}

export async function signOutBuyerAccount() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath("/");
  revalidatePath("/account");
  redirect("/login?signedOut=1");
}

export async function deleteBuyerAccount() {
  const { supabase } = await requireUser("/account/settings");
  const { data, error } = await supabase.functions.invoke("delete-account");
  const payload = data as { error?: string } | null;

  if (error || payload?.error) {
    throw new Error(payload?.error ?? error?.message ?? "Could not delete your account.");
  }

  await supabase.auth.signOut();
  redirect("/login?deleted=1");
}
