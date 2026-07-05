"use server";

import { revalidatePath } from "next/cache";

import type { AdminActionState } from "@/lib/admin-action-state";
import { requireAdminSession } from "@/lib/admin-auth";
import {
  getOrCreateAdminApplicantThread,
  getOrCreateAdminShopThread,
  listActiveAdminMessagingShops,
  markAdminApplicantThreadRead,
  markAdminShopThreadRead,
} from "@/lib/admin-messaging";
import { createAdminClient } from "@/lib/supabase/admin";
import {
  type AdminBroadcastAudience,
  sendAdminBroadcastPushNotification,
  sendChatMessagePushNotifications,
  sendDisputeResolvedPushNotification,
} from "@/lib/push-notifications";
import { createClient as createServerClient } from "@/lib/supabase/server";

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

function throwIfSupabaseError(error: { message: string } | null, fallback: string) {
  if (error) {
    throw new Error(error.message || fallback);
  }
}

async function appendDisputeResolutionMessage({
  admin,
  disputeId,
  senderId,
  body,
}: {
  admin: ReturnType<typeof createAdminClient>;
  disputeId: string;
  senderId: string;
  body: string;
}) {
  const { data: conversation } = await admin
    .from("dispute_conversations")
    .select("id")
    .eq("dispute_id", disputeId)
    .maybeSingle();

  if (conversation?.id == null) {
    return;
  }

  const { error } = await admin.from("dispute_conversation_messages").insert({
    conversation_id: conversation.id,
    sender_id: senderId,
    body,
    message_type: "text",
  });

  if (error) {
    throw new Error(error.message);
  }
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

export async function restoreApplication(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();
    const applicationId = String(formData.get("applicationId"));

    const admin = createAdminClient();
    const { error } = await admin
      .from("vendor_applications")
      .update({
        status: "pending",
        reviewed_by: null,
        reviewed_at: null,
      })
      .eq("id", applicationId)
      .eq("status", "rejected");

    throwIfSupabaseError(error, "Unable to restore application.");

    revalidatePath("/admin");
    revalidatePath("/admin/applications");

    return createSuccessState("Application restored to pending review.");
  } catch (error) {
    return createErrorState(error, "Unable to restore application.");
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

export async function toggleProductArchived(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();
    const productId = String(formData.get("productId"));
    const nextValue = String(formData.get("nextValue")) === "true";

    const admin = createAdminClient();
    // Archiving is the "delete" action: hides the product everywhere but
    // keeps the row so order history stays intact. Restoring leaves the
    // product unpublished so it can be reviewed before going live again.
    await admin
      .from("products")
      .update(
        nextValue
          ? { archived_at: new Date().toISOString(), is_published: false }
          : { archived_at: null },
      )
      .eq("id", productId);

    revalidatePath("/admin");
    revalidatePath("/admin/products");

    return createSuccessState(
      nextValue
        ? "Product archived. It is hidden from buyers but kept in order history."
        : "Product restored. It stays unpublished until you republish it.",
    );
  } catch (error) {
    return createErrorState(error, "Unable to update product archive state.");
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
    const { error } = await admin
      .from("shops")
      .update({ is_active: nextValue })
      .eq("id", shopId);
    throwIfSupabaseError(error, "Unable to update shop status.");

    revalidatePath("/admin");
    revalidatePath("/admin/shops");
    revalidatePath(`/admin/shops/${shopId}`);

    return createSuccessState(nextValue ? "Shop restored." : "Shop suspended.");
  } catch (error) {
    return createErrorState(error, "Unable to update shop status.");
  }
}

export async function deleteShop(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();
    const shopId = String(formData.get("shopId"));

    const admin = createAdminClient();
    const { error } = await admin.from("shops").delete().eq("id", shopId);
    throwIfSupabaseError(error, "Unable to delete shop.");

    revalidatePath("/admin");
    revalidatePath("/admin/shops");
    revalidatePath(`/admin/shops/${shopId}`);

    return createSuccessState("Shop deleted.");
  } catch (error) {
    return createErrorState(error, "Unable to delete shop.");
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

export async function sendAdminShopMessage(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    const session = await requireAdminSession();
    const shopId = String(formData.get("shopId") ?? "").trim();
    const body = String(formData.get("body") ?? "").trim();

    if (!shopId) {
      return createErrorState(null, "Missing shop id.");
    }

    if (!body) {
      return {
        status: "error",
        message: "Please type a message before sending.",
        savedAt: null,
      };
    }

    const thread = await getOrCreateAdminShopThread(shopId, session.user.id);
    if (!thread) {
      return createErrorState(null, "Unable to locate that shop.");
    }

    const admin = createAdminClient();
    const { data: message, error } = await admin
      .from("chat_messages")
      .insert({
        thread_id: thread.id,
        sender_id: session.user.id,
        body,
        message_type: "text",
      })
      .select("id")
      .single();

    if (error) {
      return createErrorState(new Error(error.message), "Unable to send message.");
    }

    if (message?.id != null) {
      await markAdminShopThreadRead(thread.id);
      await sendChatMessagePushNotifications([message.id]);
    }

    revalidatePath("/admin/messages");
    revalidatePath(`/admin/shops/${shopId}/messages`);
    revalidatePath(`/admin/shops/${shopId}`);

    return createSuccessState("Message sent.");
  } catch (error) {
    return createErrorState(error, "Unable to send message.");
  }
}

export async function sendAdminApplicantMessage(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    const session = await requireAdminSession();
    const applicantUserId = String(formData.get("applicantUserId") ?? "").trim();
    const body = String(formData.get("body") ?? "").trim();

    if (!applicantUserId) {
      return createErrorState(null, "Missing applicant id.");
    }

    if (!body) {
      return {
        status: "error",
        message: "Please type a message before sending.",
        savedAt: null,
      };
    }

    const thread = await getOrCreateAdminApplicantThread(
      applicantUserId,
      session.user.id,
    );
    if (!thread) {
      return createErrorState(null, "Unable to locate that applicant.");
    }

    const admin = createAdminClient();
    const { data: message, error } = await admin
      .from("chat_messages")
      .insert({
        thread_id: thread.id,
        sender_id: session.user.id,
        body,
        message_type: "text",
      })
      .select("id")
      .single();

    if (error) {
      return createErrorState(new Error(error.message), "Unable to send message.");
    }

    if (message?.id != null) {
      await markAdminApplicantThreadRead(thread.id);
      await sendChatMessagePushNotifications([message.id]);
    }

    revalidatePath("/admin/applications");
    revalidatePath(`/admin/applications/${applicantUserId}/messages`);

    return createSuccessState("Message sent.");
  } catch (error) {
    return createErrorState(error, "Unable to send message.");
  }
}

export async function sendAdminBroadcastMessage(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    const session = await requireAdminSession();
    const body = String(formData.get("body") ?? "").trim();

    if (!body) {
      return {
        status: "error",
        message: "Please type a message before sending.",
        savedAt: null,
      };
    }

    const shops = await listActiveAdminMessagingShops();
    if (shops.length === 0) {
      return createErrorState(null, "No active stores are available to message.");
    }

    const threads = await Promise.all(
      shops.map((shop) => getOrCreateAdminShopThread(shop.id, session.user.id)),
    );
    const messageRows = threads
      .filter((thread): thread is NonNullable<typeof thread> => thread != null)
      .map((thread) => ({
        thread_id: thread.id,
        sender_id: session.user.id,
        body,
        message_type: "text",
      }));

    if (messageRows.length === 0) {
      return createErrorState(null, "Could not locate any shop threads for this broadcast.");
    }

    const admin = createAdminClient();
    const { data: messages, error } = await admin
      .from("chat_messages")
      .insert(messageRows)
      .select("id");
    if (error) {
      return createErrorState(new Error(error.message), "Unable to send broadcast.");
    }

    await sendChatMessagePushNotifications(
      (messages ?? []).map((message) => message.id),
    );

    revalidatePath("/admin/messages");
    revalidatePath("/admin/shops");

    return createSuccessState(`Message sent to ${messageRows.length} stores.`);
  } catch (error) {
    return createErrorState(error, "Unable to send broadcast.");
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
    const supabase = await createServerClient();
    const now = new Date().toISOString();

    const releaseResult = await supabase.functions.invoke("release-escrow", {
      body: {
        orderId,
      },
    });
    if (releaseResult.error) {
      throw new Error(releaseResult.error.message);
    }

    const disputeUpdate = await admin
      .from("disputes")
      .update({
        status: "resolved",
        resolution,
        resolved_by: session.user.id,
        resolved_at: now,
      })
      .eq("id", disputeId);
    if (disputeUpdate.error) {
      throw new Error(disputeUpdate.error.message);
    }

    await appendDisputeResolutionMessage({
      admin,
      disputeId,
      senderId: session.user.id,
      body: `Admin resolution: funds released to the seller.\n\n${resolution}`,
    });

    await sendDisputeResolvedPushNotification({ orderId, disputeId });

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
    const supabase = await createServerClient();
    const now = new Date().toISOString();

    const refundResult = await supabase.functions.invoke("process-refund", {
      body: {
        orderId,
        reason: resolution,
      },
    });
    if (refundResult.error) {
      throw new Error(refundResult.error.message);
    }

    const disputeUpdate = await admin
      .from("disputes")
      .update({
        status: "resolved",
        resolution,
        resolved_by: session.user.id,
        resolved_at: now,
      })
      .eq("id", disputeId);
    if (disputeUpdate.error) {
      throw new Error(disputeUpdate.error.message);
    }

    await appendDisputeResolutionMessage({
      admin,
      disputeId,
      senderId: session.user.id,
      body: `Admin resolution: buyer refunded.\n\n${resolution}`,
    });

    await sendDisputeResolvedPushNotification({ orderId, disputeId });

    revalidatePath("/admin");
    revalidatePath("/admin/disputes");
    revalidatePath("/admin/orders");

    return createSuccessState("Buyer refunded.");
  } catch (error) {
    return createErrorState(error, "Unable to refund buyer.");
  }
}

const broadcastAudiences: AdminBroadcastAudience[] = [
  "user",
  "all_vendors",
  "all_buyers",
  "subscribed_vendors",
  "vendors_without_shop",
];

export async function sendAdminPushNotification(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();

    const title = String(formData.get("title") ?? "").trim();
    const body = String(formData.get("body") ?? "").trim();
    const route = String(formData.get("route") ?? "").trim();
    const audienceValue = String(formData.get("audience") ?? "").trim();
    const userId = String(formData.get("userId") ?? "").trim();

    if (!title) {
      return createErrorState(null, "Please enter a notification title.");
    }
    if (!body) {
      return createErrorState(null, "Please enter a notification message.");
    }
    if (route && !route.startsWith("/")) {
      return createErrorState(null, "The app link must start with / (e.g. /learn).");
    }

    const audience = broadcastAudiences.find((value) => value === audienceValue);
    if (!audience) {
      return createErrorState(null, "Please choose an audience.");
    }
    if (audience === "user" && !userId) {
      return createErrorState(null, "Please search for and select a recipient first.");
    }

    const result = await sendAdminBroadcastPushNotification({
      title,
      body,
      route: route || null,
      audience,
      userId: audience === "user" ? userId : null,
    });

    if (result.recipients === 0) {
      return createErrorState(null, "No users matched the selected audience.");
    }

    return createSuccessState(
      `Notification sent to ${result.recipients} ${
        result.recipients === 1 ? "user" : "users"
      } (${result.sent} ${result.sent === 1 ? "device" : "devices"} reached${
        result.failed > 0 ? `, ${result.failed} failed` : ""
      }).`,
    );
  } catch (error) {
    return createErrorState(error, "Unable to send push notification.");
  }
}

// ============================================================
// Learning hub (podcasts / videos / articles)
// ============================================================

function learningString(formData: FormData, key: string): string {
  const value = formData.get(key);
  return typeof value === "string" ? value.trim() : "";
}

function learningNullableString(formData: FormData, key: string): string | null {
  const value = learningString(formData, key);
  return value.length > 0 ? value : null;
}

function learningChecked(formData: FormData, key: string): boolean {
  const value = formData.get(key);
  return value === "on" || value === "true" || value === "1";
}

async function uploadLearningThumbnail(file: File): Promise<string> {
  const admin = createAdminClient();
  const extension = file.name.includes(".") ? file.name.split(".").pop() : "jpg";
  const path = `${crypto.randomUUID()}.${extension}`;
  const { error } = await admin.storage.from("learning-assets").upload(path, file, {
    contentType: file.type || "image/jpeg",
    upsert: false,
  });
  if (error) {
    throw new Error("Unable to upload thumbnail.");
  }
  return admin.storage.from("learning-assets").getPublicUrl(path).data.publicUrl;
}

export async function saveLearningResource(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();

    const resourceId = learningString(formData, "resourceId");
    const title = learningString(formData, "title");
    const contentUrl = learningString(formData, "contentUrl");
    const typeValue = learningString(formData, "type");
    const type =
      typeValue === "podcast" || typeValue === "video" ? typeValue : "article";

    if (!title) {
      throw new Error("Title is required.");
    }
    if (!contentUrl || !/^https?:\/\//i.test(contentUrl)) {
      throw new Error("A valid link (https://...) is required.");
    }

    const sortOrderRaw = learningString(formData, "sortOrder");
    const sortOrder = Number.parseInt(sortOrderRaw, 10);

    const thumbnailFile = formData.get("thumbnail");
    let thumbnailUrl = learningNullableString(formData, "existingThumbnailUrl");
    if (
      typeof File !== "undefined" &&
      thumbnailFile instanceof File &&
      thumbnailFile.size > 0
    ) {
      thumbnailUrl = await uploadLearningThumbnail(thumbnailFile);
    }

    const payload = {
      type,
      title,
      description: learningNullableString(formData, "description"),
      content_url: contentUrl,
      thumbnail_url: thumbnailUrl,
      author: learningNullableString(formData, "author"),
      duration_label: learningNullableString(formData, "durationLabel"),
      is_published: learningChecked(formData, "isPublished"),
      is_featured: learningChecked(formData, "isFeatured"),
      sort_order: Number.isFinite(sortOrder) ? sortOrder : 0,
    };

    const admin = createAdminClient();
    if (resourceId) {
      const { error } = await admin
        .from("learning_resources")
        .update(payload)
        .eq("id", resourceId);
      throwIfSupabaseError(error, "Unable to update learning resource.");
    } else {
      const { error } = await admin.from("learning_resources").insert(payload);
      throwIfSupabaseError(error, "Unable to create learning resource.");
    }

    revalidatePath("/admin/learning");
    revalidatePath("/learn");

    return createSuccessState(resourceId ? "Resource updated." : "Resource added.");
  } catch (error) {
    return createErrorState(error, "Unable to save learning resource.");
  }
}

export async function deleteLearningResource(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    await requireAdminSession();

    const resourceId = learningString(formData, "resourceId");
    if (!resourceId) {
      throw new Error("Missing resource id.");
    }

    const admin = createAdminClient();
    const { error } = await admin
      .from("learning_resources")
      .delete()
      .eq("id", resourceId);
    throwIfSupabaseError(error, "Unable to delete learning resource.");

    revalidatePath("/admin/learning");
    revalidatePath("/learn");

    return createSuccessState("Resource deleted.");
  } catch (error) {
    return createErrorState(error, "Unable to delete learning resource.");
  }
}
