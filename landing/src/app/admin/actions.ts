"use server";

import { revalidatePath } from "next/cache";

import { requireAdminSession } from "@/lib/admin-auth";
import { createAdminClient } from "@/lib/supabase/admin";

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export async function approveApplication(formData: FormData) {
  const session = await requireAdminSession();
  const applicationId = String(formData.get("applicationId"));
  const userId = String(formData.get("userId"));
  const businessName = String(formData.get("businessName"));
  const location = String(formData.get("location") ?? "");

  const admin = createAdminClient();

  await admin
    .from("vendor_applications")
    .update({
      status: "approved",
      reviewed_by: session.user.id,
      reviewed_at: new Date().toISOString(),
    })
    .eq("id", applicationId);

  await admin
    .from("profiles")
    .update({
      role: "vendor",
    })
    .eq("id", userId);

  const { data: existingShop } = await admin
    .from("shops")
    .select("id")
    .eq("vendor_id", userId)
    .maybeSingle();

  if (!existingShop) {
    const baseSlug = slugify(businessName);
    const slug = `${baseSlug}-${Date.now().toString().slice(-6)}`;

    await admin.from("shops").insert({
      vendor_id: userId,
      name: businessName,
      slug,
      bio: `Welcome to ${businessName}.`,
      location: location || null,
      is_active: true,
    });
  }

  revalidatePath("/admin");
  revalidatePath("/admin/applications");
}

export async function rejectApplication(formData: FormData) {
  const session = await requireAdminSession();
  const applicationId = String(formData.get("applicationId"));

  const admin = createAdminClient();
  await admin
    .from("vendor_applications")
    .update({
      status: "rejected",
      reviewed_by: session.user.id,
      reviewed_at: new Date().toISOString(),
    })
    .eq("id", applicationId);

  revalidatePath("/admin");
  revalidatePath("/admin/applications");
}

export async function toggleProductPublish(formData: FormData) {
  await requireAdminSession();
  const productId = String(formData.get("productId"));
  const nextValue = String(formData.get("nextValue")) === "true";

  const admin = createAdminClient();
  await admin
    .from("products")
    .update({ is_published: nextValue })
    .eq("id", productId);

  revalidatePath("/admin");
  revalidatePath("/admin/products");
}

export async function toggleShopStatus(formData: FormData) {
  await requireAdminSession();
  const shopId = String(formData.get("shopId"));
  const nextValue = String(formData.get("nextValue")) === "true";

  const admin = createAdminClient();
  await admin.from("shops").update({ is_active: nextValue }).eq("id", shopId);

  revalidatePath("/admin");
  revalidatePath("/admin/shops");
  revalidatePath(`/admin/shops/${shopId}`);
}

export async function toggleShopPostPublish(formData: FormData) {
  await requireAdminSession();
  const shopId = String(formData.get("shopId"));
  const postId = String(formData.get("postId"));
  const nextValue = String(formData.get("nextValue")) === "true";

  const admin = createAdminClient();
  await admin
    .from("shop_posts")
    .update({ is_published: nextValue })
    .eq("id", postId);

  revalidatePath("/admin");
  revalidatePath("/admin/shops");
  revalidatePath(`/admin/shops/${shopId}`);
}

export async function createShopNote(formData: FormData) {
  const session = await requireAdminSession();
  const shopId = String(formData.get("shopId"));
  const note = String(formData.get("note") ?? "").trim();

  if (!note) {
    return;
  }

  const admin = createAdminClient();
  await admin.from("admin_shop_notes").insert({
    shop_id: shopId,
    note,
    created_by: session.user.id,
  });

  revalidatePath("/admin");
  revalidatePath("/admin/shops");
  revalidatePath(`/admin/shops/${shopId}`);
}

export async function resolveDisputeRelease(formData: FormData) {
  const session = await requireAdminSession();
  const disputeId = String(formData.get("disputeId"));
  const orderId = String(formData.get("orderId"));
  const resolution = String(formData.get("resolution"));

  const admin = createAdminClient();
  const now = new Date().toISOString();

  await admin.functions.invoke("release-escrow", {
    body: {
      orderId,
    },
  });

  await admin
    .from("disputes")
    .update({
      status: "resolved",
      resolution,
      resolved_by: session.user.id,
      resolved_at: now,
    })
    .eq("id", disputeId);

  revalidatePath("/admin");
  revalidatePath("/admin/disputes");
  revalidatePath("/admin/orders");
}

export async function resolveDisputeRefund(formData: FormData) {
  const session = await requireAdminSession();
  const disputeId = String(formData.get("disputeId"));
  const orderId = String(formData.get("orderId"));
  const resolution = String(formData.get("resolution"));

  const admin = createAdminClient();
  const now = new Date().toISOString();

  await admin.functions.invoke("process-refund", {
    body: {
      orderId,
      reason: resolution,
    },
  });

  await admin
    .from("disputes")
    .update({
      status: "resolved",
      resolution,
      resolved_by: session.user.id,
      resolved_at: now,
    })
    .eq("id", disputeId);

  revalidatePath("/admin");
  revalidatePath("/admin/disputes");
  revalidatePath("/admin/orders");
}
