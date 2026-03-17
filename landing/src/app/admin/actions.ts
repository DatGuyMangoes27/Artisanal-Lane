"use server";

import { revalidatePath } from "next/cache";

import type { AdminActionState } from "@/lib/admin-action-state";
import { requireAdminSession } from "@/lib/admin-auth";
import { createAdminClient } from "@/lib/supabase/admin";

function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function createSuccessState(message: string): AdminActionState {
  return {
    status: "success",
    message,
    savedAt: new Date().toISOString(),
  };
}

function createErrorState(error: unknown, fallback: string): AdminActionState {
  return {
    status: "error",
    message: error instanceof Error ? error.message : fallback,
    savedAt: null,
  };
}

export async function approveApplication(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
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

    return createSuccessState("Application approved.");
  } catch (error) {
    return createErrorState(error, "Unable to approve application.");
  }
}

export async function rejectApplication(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
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

    return createSuccessState("Application rejected.");
  } catch (error) {
    return createErrorState(error, "Unable to reject application.");
  }
}

export async function toggleProductPublish(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
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

    return createSuccessState(nextValue ? "Product published." : "Product unpublished.");
  } catch (error) {
    return createErrorState(error, "Unable to update product visibility.");
  }
}

export async function toggleProductFeatured(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();
    const productId = String(formData.get("productId"));
    const nextValue = String(formData.get("nextValue")) === "true";

    const admin = createAdminClient();
    await admin
      .from("products")
      .update({
        is_featured: nextValue,
        featured_at: nextValue ? new Date().toISOString() : null,
      })
      .eq("id", productId);

    revalidatePath("/admin");
    revalidatePath("/admin/products");

    return createSuccessState(nextValue ? "Product featured." : "Product unfeatured.");
  } catch (error) {
    return createErrorState(error, "Unable to update featured status.");
  }
}

export async function toggleShopStatus(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();
    const shopId = String(formData.get("shopId"));
    const nextValue = String(formData.get("nextValue")) === "true";

    const admin = createAdminClient();
    await admin.from("shops").update({ is_active: nextValue }).eq("id", shopId);

    revalidatePath("/admin");
    revalidatePath("/admin/shops");
    revalidatePath(`/admin/shops/${shopId}`);

    return createSuccessState(nextValue ? "Shop restored." : "Shop suspended.");
  } catch (error) {
    return createErrorState(error, "Unable to update shop status.");
  }
}

export async function toggleShopSpotlight(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();
    const shopId = String(formData.get("shopId"));
    const nextValue = String(formData.get("nextValue")) === "true";

    const admin = createAdminClient();

    if (nextValue) {
      await admin.from("shops").update({ is_spotlight: false }).eq("is_spotlight", true);
    }

    await admin
      .from("shops")
      .update({
        is_spotlight: nextValue,
        spotlighted_at: nextValue ? new Date().toISOString() : null,
      })
      .eq("id", shopId);

    revalidatePath("/admin");
    revalidatePath("/admin/shops");
    revalidatePath(`/admin/shops/${shopId}`);

    return createSuccessState(nextValue ? "Artist spotlight updated." : "Artist spotlight removed.");
  } catch (error) {
    return createErrorState(error, "Unable to update artist spotlight.");
  }
}

export async function toggleShopPostPublish(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
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

    return createSuccessState(nextValue ? "Post republished." : "Post unpublished.");
  } catch (error) {
    return createErrorState(error, "Unable to update post visibility.");
  }
}

export async function createShopNote(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    const session = await requireAdminSession();
    const shopId = String(formData.get("shopId"));
    const note = String(formData.get("note") ?? "").trim();

    if (!note) {
      return {
        status: "error",
        message: "Please enter a note before saving.",
        savedAt: null,
      };
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

    return createSuccessState("Note saved.");
  } catch (error) {
    return createErrorState(error, "Unable to save note.");
  }
}

export async function updateStationeryRequest(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    const session = await requireAdminSession();
    const requestId = String(formData.get("requestId") ?? "").trim();
    const status = String(formData.get("status") ?? "").trim();
    const courierName = String(formData.get("courierName") ?? "").trim() || null;
    const trackingNumber =
      String(formData.get("trackingNumber") ?? "").trim() || null;
    const adminNotes = String(formData.get("adminNotes") ?? "").trim() || null;

    if (!requestId) {
      return createErrorState(null, "Missing stationery request id.");
    }

    if (!status) {
      return createErrorState(null, "Please choose a status before saving.");
    }

    const admin = createAdminClient();
    const update: Record<string, string | null> = {
      status,
      courier_name: courierName,
      tracking_number: trackingNumber,
      admin_notes: adminNotes,
    };

    if (status === "shipped" || status === "delivered") {
      update.fulfilled_by = session.user.id;
      update.fulfilled_at = new Date().toISOString();
    }

    const { error } = await admin
      .from("stationery_requests")
      .update(update)
      .eq("id", requestId);

    if (error) {
      return createErrorState(new Error(error.message), "Unable to save update.");
    }

    revalidatePath("/admin");
    revalidatePath("/admin/stationery");

    return createSuccessState("Saved successfully.");
  } catch (error) {
    return createErrorState(error, "Unable to save update.");
  }
}

export async function resolveDisputeRelease(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
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

    return createSuccessState("Funds released.");
  } catch (error) {
    return createErrorState(error, "Unable to release funds.");
  }
}

export async function resolveDisputeRefund(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
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

    return createSuccessState("Buyer refunded.");
  } catch (error) {
    return createErrorState(error, "Unable to refund buyer.");
  }
}
