"use server";

import { revalidatePath } from "next/cache";
import { notFound, redirect } from "next/navigation";

import { createAdminClient } from "@/lib/supabase/admin";
import { sendChatMessagePushNotifications } from "@/lib/push-notifications";
import {
  getVendorProduct,
  getVendorShop,
  getVendorShopPost,
  getVendorSubscription,
  requireVendorSession,
  requireVendorShop,
} from "@/lib/marketplace/vendor-data";
import {
  isVendorSubscriptionActive,
  parseCurrencyInput,
  parseFulfillmentMode,
  parseIntegerInput,
  parseJsonArrayInput,
  parseListInput,
  parseNullableCurrencyInput,
  parseNullableIntegerInput,
  parseNullableText,
  parseRequiredText,
} from "@/lib/marketplace/vendor-utils";
import { SHIPPING_METHOD_KEYS } from "@/lib/marketplace/shipping";

type JsonRecord = Record<string, unknown>;

const shippingKeys = SHIPPING_METHOD_KEYS;

function isFile(value: FormDataEntryValue | null): value is File {
  return typeof File !== "undefined" && value instanceof File && value.size > 0;
}

function isTruthy(value: FormDataEntryValue | null) {
  return value === "on" || value === "true" || value === "1";
}

function requireId(formData: FormData, key: string) {
  const value = parseRequiredText(formData.get(key));
  if (value === "null" || value === "undefined") {
    throw new Error(`Missing ${key}.`);
  }
  return value;
}

function slugify(value: string) {
  const slug = value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  return slug || "artisan-shop";
}

async function uploadPublicFile({
  bucket,
  ownerId,
  file,
}: {
  bucket: string;
  ownerId: string;
  file: File;
}) {
  const admin = createAdminClient();
  const extension = file.name.includes(".") ? file.name.split(".").pop() : "bin";
  const path = `${ownerId}/${crypto.randomUUID()}.${extension}`;
  const { error } = await admin.storage.from(bucket).upload(path, file, {
    contentType: file.type || "application/octet-stream",
    upsert: false,
  });

  if (error) {
    throw new Error(`Unable to upload ${file.name}.`, { cause: error });
  }

  return admin.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

async function getUploadedUrls(formData: FormData, key: string, bucket: string, ownerId: string) {
  const files = formData.getAll(key).filter(isFile);
  const uploaded = await Promise.all(files.map((file) => uploadPublicFile({ bucket, ownerId, file })));
  return uploaded;
}

function parseImageUrls(formData: FormData, key: string) {
  return parseListInput(formData.get(key)).filter((url) => url.startsWith("http"));
}

function parseShippingOptions(formData: FormData) {
  // Persist the same JSONB shape the mobile app reads/writes
  // (snake_case market fields, omitted when empty).
  return shippingKeys.map((key) => {
    const marketName =
      key === "market_pickup" ? parseNullableText(formData.get(`shipping_market_name_${key}`)) : null;
    const marketLocation =
      key === "market_pickup"
        ? parseNullableText(formData.get(`shipping_market_location_${key}`))
        : null;
    const marketProvince =
      key === "market_pickup"
        ? parseNullableText(formData.get(`shipping_market_province_${key}`))
        : null;

    return {
      key,
      enabled: isTruthy(formData.get(`shipping_${key}`)),
      price: parseCurrencyInput(formData.get(`shipping_price_${key}`)),
      ...(marketName ? { market_name: marketName } : {}),
      ...(marketLocation ? { market_location: marketLocation } : {}),
      ...(marketProvince ? { market_province: marketProvince } : {}),
    };
  });
}

export type VendorApplicationState = { error: string | null };

export async function submitVendorApplication(
  _prevState: VendorApplicationState,
  formData: FormData,
): Promise<VendorApplicationState> {
  const session = await requireVendorSession("/vendor/apply");

  // Already an approved artisan (or admin) — nothing to apply for.
  if (session.isApprovedVendor) {
    redirect("/vendor");
  }

  const userId = session.user.id;
  const admin = createAdminClient();

  // Don't create a duplicate while an application is already in flight.
  const { data: existing } = await admin
    .from("vendor_applications")
    .select("id")
    .or(`user_id.eq.${userId},applicant_user_id_snapshot.eq.${userId}`)
    .is("superseded_at", null)
    .limit(1)
    .maybeSingle();

  if (existing) {
    redirect("/vendor");
  }

  const businessName = parseNullableText(formData.get("businessName"));
  if (!businessName) {
    return { error: "Please enter your business or shop name." };
  }

  if (!isTruthy(formData.get("acceptTerms"))) {
    return { error: "Please accept the Terms & Conditions to continue." };
  }

  // Screening needs something to look at: a portfolio link or product photos.
  const portfolioUrl = parseNullableText(formData.get("portfolioUrl"));
  const hasProofFiles = formData
    .getAll("proofImages")
    .some((entry) => entry instanceof File && entry.size > 0);

  if (!portfolioUrl && !hasProofFiles) {
    return {
      error:
        "Please add a portfolio or social link, or upload at least one photo of your work, so we can review your application.",
    };
  }

  const proofImageUrls = await getUploadedUrls(
    formData,
    "proofImages",
    "shop-assets",
    `${userId}/vendor-application`,
  );

  const { error } = await admin.from("vendor_applications").insert({
    user_id: userId,
    applicant_user_id_snapshot: userId,
    applicant_display_name_snapshot: session.profile.displayName,
    applicant_email_snapshot: session.profile.email,
    business_name: businessName,
    motivation: parseNullableText(formData.get("motivation")),
    portfolio_url: portfolioUrl,
    proof_image_urls: proofImageUrls,
    location: parseNullableText(formData.get("location")),
    delivery_info: parseNullableText(formData.get("deliveryInfo")),
    turnaround_time: parseNullableText(formData.get("turnaroundTime")),
    status: "pending",
  });

  if (error) {
    return { error: "We couldn't submit your application. Please try again." };
  }

  revalidatePath("/vendor");
  redirect("/vendor");
}

export async function updateVendorShopSettings(formData: FormData) {
  const session = await requireVendorSession("/vendor/profile/shop");
  if (!session.isApprovedVendor) {
    redirect("/vendor");
  }

  const { user } = session;
  const shop = await getVendorShop(user.id);
  const logoUploads = await getUploadedUrls(formData, "logoFile", "shop-assets", user.id);
  const coverUploads = await getUploadedUrls(formData, "coverFile", "shop-assets", user.id);
  const name = parseRequiredText(formData.get("name"));

  const update = {
    name,
    bio: parseNullableText(formData.get("bio")),
    brand_story: parseNullableText(formData.get("brandStory")),
    location: parseNullableText(formData.get("location")),
    logo_url: logoUploads[0] ?? parseNullableText(formData.get("logoUrl")),
    cover_image_url: coverUploads[0] ?? parseNullableText(formData.get("coverImageUrl")),
    is_offline: isTruthy(formData.get("isOffline")),
    back_to_work_date: isTruthy(formData.get("isOffline"))
      ? parseNullableText(formData.get("backToWorkDate"))
      : null,
    shipping_options: parseShippingOptions(formData),
  };

  const admin = createAdminClient();
  const result = shop
    ? await admin.from("shops").update(update).eq("id", shop.id).eq("vendor_id", user.id)
    : await admin.from("shops").insert({
        ...update,
        vendor_id: user.id,
        slug: `${slugify(name)}-${Date.now().toString().slice(-6)}`,
        is_active: true,
      });

  const { error } = result;
  if (error) {
    throw new Error("Unable to save shop settings.", { cause: error });
  }

  revalidatePath("/vendor");
  revalidatePath("/vendor/profile/shop");
}

export async function createVendorMarketEvent(formData: FormData) {
  const { shop } = await requireVendorShop("/vendor/profile/shop");
  const admin = createAdminClient();
  const { error } = await admin.from("shop_market_events").insert({
    shop_id: shop.id,
    market_name: parseRequiredText(formData.get("marketName")),
    location: parseRequiredText(formData.get("marketLocation")),
    event_date: parseRequiredText(formData.get("eventDate")),
    time_label: parseNullableText(formData.get("timeLabel")),
    notes: parseNullableText(formData.get("notes")),
    is_active: isTruthy(formData.get("isActive")),
  });

  if (error) {
    throw new Error("Unable to add market event.", { cause: error });
  }

  revalidatePath("/vendor/profile/shop");
}

export async function deleteVendorMarketEvent(formData: FormData) {
  const { shop } = await requireVendorShop("/vendor/profile/shop");
  const eventId = requireId(formData, "eventId");
  const admin = createAdminClient();
  const { error } = await admin
    .from("shop_market_events")
    .delete()
    .eq("id", eventId)
    .eq("shop_id", shop.id);

  if (error) {
    throw new Error("Unable to delete market event.", { cause: error });
  }

  revalidatePath("/vendor/profile/shop");
}

function variantPayloadFromJson(value: unknown, productId: string) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((entry, index) => {
    const row = entry != null && typeof entry === "object" ? (entry as JsonRecord) : {};
    const displayName = String(row.displayName ?? row.display_name ?? row.color_name ?? `Variant ${index + 1}`);
    return {
      product_id: productId,
      color_name: displayName,
      display_name: displayName,
      option_values: Array.isArray(row.optionValues)
        ? row.optionValues
        : Array.isArray(row.option_values)
          ? row.option_values
          : [displayName],
      price: parseCurrencyInput(String(row.price ?? 0)),
      compare_at_price:
        row.compareAtPrice == null && row.compare_at_price == null
          ? null
          : parseCurrencyInput(String(row.compareAtPrice ?? row.compare_at_price)),
      stock_qty: parseIntegerInput(String(row.stockQty ?? row.stock_qty ?? 0)),
      images: Array.isArray(row.images) ? row.images.map(String).filter(Boolean) : [],
      is_active: row.isActive !== false && row.is_active !== false,
      sort_order: Number.isFinite(Number(row.sortOrder ?? row.sort_order))
        ? Number(row.sortOrder ?? row.sort_order)
        : index,
    };
  });
}

async function productPayloadFromForm(formData: FormData, shopId: string, userId: string) {
  const uploadedImages = await getUploadedUrls(formData, "productImages", "product-images", userId);
  const existingImages = parseImageUrls(formData, "imageUrls");
  const images = [...existingImages, ...uploadedImages];
  const categoryId = parseNullableText(formData.get("categoryId"));
  const subcategoryId = parseNullableText(formData.get("subcategoryId"));

  return {
    shop_id: shopId,
    category_id: categoryId,
    subcategory_id: subcategoryId,
    title: parseRequiredText(formData.get("title")),
    description: parseNullableText(formData.get("description")),
    price: parseCurrencyInput(formData.get("price")),
    compare_at_price: parseCurrencyInput(formData.get("compareAtPrice")) || null,
    stock_qty: parseIntegerInput(formData.get("stockQty")),
    images,
    tags: parseListInput(formData.get("tags")),
    care_instructions: parseNullableText(formData.get("careInstructions")),
    shipping_options: parseShippingOptions(formData),
    option_groups: parseJsonArrayInput(formData.get("optionGroupsJson")),
    fulfillment_mode: parseFulfillmentMode(formData.get("fulfillmentMode")),
    made_to_order_price: parseNullableCurrencyInput(formData.get("madeToOrderPrice")),
    made_to_order_lead_min_days: parseNullableIntegerInput(formData.get("leadMinDays")),
    made_to_order_lead_max_days: parseNullableIntegerInput(formData.get("leadMaxDays")),
    made_to_order_capacity: parseNullableIntegerInput(formData.get("madeToOrderCapacity")),
    made_to_order_allow_custom_note: isTruthy(formData.get("allowCustomNote")),
    is_published: isTruthy(formData.get("isPublished")),
  };
}

// Mirrors the database RLS gate (vendor_subscription_is_active) that protects
// product writes on the mobile app. The web product actions use the service
// role client, which bypasses RLS, so the subscription must be enforced here
// too — otherwise vendors could list products without an active subscription.
async function requireActiveVendorSubscription(vendorId: string) {
  const subscription = await getVendorSubscription(vendorId);
  if (!isVendorSubscriptionActive(subscription)) {
    redirect("/vendor/profile/subscription?needsSubscription=1");
  }
}

export async function createVendorProduct(formData: FormData) {
  const { shop, user } = await requireVendorShop("/vendor/products/new");
  await requireActiveVendorSubscription(user.id);
  const payload = await productPayloadFromForm(formData, shop.id, user.id);
  const admin = createAdminClient();
  const { data, error } = await admin.from("products").insert(payload).select("id").single();
  if (error || !data) {
    throw new Error("Unable to create product.", { cause: error });
  }

  const variants = variantPayloadFromJson(parseJsonArrayInput(formData.get("variantsJson")), data.id);
  if (variants.length > 0) {
    const { error: variantsError } = await admin.from("product_variants").insert(variants);
    if (variantsError) {
      throw new Error("Product was created, but variants could not be saved.", { cause: variantsError });
    }
  }

  revalidatePath("/vendor/products");
  redirect(`/vendor/products/${data.id}`);
}

export async function updateVendorProduct(formData: FormData) {
  const { shop, user } = await requireVendorShop("/vendor/products");
  await requireActiveVendorSubscription(user.id);
  const productId = requireId(formData, "productId");
  const product = await getVendorProduct(shop.id, productId);
  if (!product) {
    notFound();
  }

  const payload = await productPayloadFromForm(formData, shop.id, user.id);
  const admin = createAdminClient();
  const { error } = await admin
    .from("products")
    .update(payload)
    .eq("id", productId)
    .eq("shop_id", shop.id);
  if (error) {
    throw new Error("Unable to update product.", { cause: error });
  }

  const variants = variantPayloadFromJson(parseJsonArrayInput(formData.get("variantsJson")), productId);
  await admin.from("product_variants").delete().eq("product_id", productId);
  if (variants.length > 0) {
    const { error: variantsError } = await admin.from("product_variants").insert(variants);
    if (variantsError) {
      throw new Error("Unable to save variants.", { cause: variantsError });
    }
  }

  revalidatePath("/vendor/products");
  revalidatePath(`/vendor/products/${productId}`);
}

export async function deleteVendorProduct(formData: FormData) {
  const { shop } = await requireVendorShop("/vendor/products");
  const productId = requireId(formData, "productId");
  const admin = createAdminClient();
  const { error } = await admin
    .from("products")
    .update({ archived_at: new Date().toISOString(), is_published: false })
    .eq("id", productId)
    .eq("shop_id", shop.id);

  if (error) {
    throw new Error("Unable to archive product.", { cause: error });
  }

  revalidatePath("/vendor/products");
  redirect("/vendor/products");
}

export async function markVendorOrderShipped(formData: FormData) {
  const { supabase, shop, user } = await requireVendorShop("/vendor/orders");
  const orderId = requireId(formData, "orderId");
  const admin = createAdminClient();
  const { data: order } = await admin
    .from("orders")
    .select("id")
    .eq("id", orderId)
    .eq("shop_id", shop.id)
    .maybeSingle();
  if (!order) {
    notFound();
  }

  const { data: sessionResult } = await supabase.auth.getSession();
  const accessToken = sessionResult.session?.access_token;
  const { data, error } = await supabase.functions.invoke("mark-order-shipped", {
    headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
    body: {
      orderId,
      trackingNumber: parseNullableText(formData.get("trackingNumber")),
      trackingUrl: parseNullableText(formData.get("trackingUrl")),
      userId: user.id,
    },
  });

  if (error || (data as { error?: string } | null)?.error) {
    throw new Error((data as { error?: string } | null)?.error ?? "Unable to mark order shipped.", {
      cause: error,
    });
  }

  revalidatePath("/vendor/orders");
  revalidatePath(`/vendor/orders/${orderId}`);
}

export async function saveVendorPayoutDetails(formData: FormData) {
  const { user } = await requireVendorSession("/vendor/profile/payouts");
  const identityNumber = parseRequiredText(formData.get("identityNumber"));
  const admin = createAdminClient();
  const { error } = await admin.from("vendor_payout_profiles").upsert({
    vendor_id: user.id,
    account_holder_name: parseRequiredText(formData.get("accountHolderName")),
    bank_name: parseRequiredText(formData.get("bankName")),
    account_number: parseRequiredText(formData.get("accountNumber")),
    branch_code: parseRequiredText(formData.get("branchCode")),
    account_type: parseRequiredText(formData.get("accountType")),
    registered_phone: parseRequiredText(formData.get("registeredPhone")),
    registered_email: parseRequiredText(formData.get("registeredEmail")),
    identity_number: identityNumber,
    business_registration_number: parseNullableText(formData.get("businessRegistrationNumber")),
    verification_status: "verified",
    status_notes: null,
  });

  if (error) {
    throw new Error("Unable to save payout details.", { cause: error });
  }

  revalidatePath("/vendor");
  revalidatePath("/vendor/profile/payouts");
}

export async function startVendorSubscription() {
  const { supabase } = await requireVendorSession("/vendor/profile/subscription");
  const { data: sessionResult } = await supabase.auth.getSession();
  const accessToken = sessionResult.session?.access_token;
  const { data, error } = await supabase.functions.invoke("create-payfast-subscription", {
    headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
  });

  const checkoutUrl = (data as { checkoutUrl?: string; paymentUrl?: string; url?: string } | null)?.checkoutUrl
    ?? (data as { paymentUrl?: string } | null)?.paymentUrl
    ?? (data as { url?: string } | null)?.url;

  if (error || !checkoutUrl) {
    throw new Error("Unable to start subscription checkout.", { cause: error });
  }

  redirect(checkoutUrl);
}

export async function cancelVendorSubscription() {
  const { supabase } = await requireVendorSession("/vendor/profile/subscription");
  const { data: sessionResult } = await supabase.auth.getSession();
  const accessToken = sessionResult.session?.access_token;
  const { data, error } = await supabase.functions.invoke("cancel-payfast-subscription", {
    headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
  });

  if (error || (data as { error?: string } | null)?.error) {
    throw new Error((data as { error?: string } | null)?.error ?? "Unable to cancel subscription.", {
      cause: error,
    });
  }

  revalidatePath("/vendor");
  revalidatePath("/vendor/profile/subscription");
}

export async function createStationeryCheckout(formData: FormData) {
  const { supabase, shop } = await requireVendorShop("/vendor/profile/stationery");
  const items = parseJsonArrayInput(formData.get("itemsJson"));
  if (items.length === 0) {
    throw new Error("Select at least one stationery item.");
  }

  const { data: sessionResult } = await supabase.auth.getSession();
  const accessToken = sessionResult.session?.access_token;
  const { data, error } = await supabase.functions.invoke("create-payfast-stationery-checkout", {
    headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
    body: {
      shopId: shop.id,
      items,
      notes: parseNullableText(formData.get("notes")),
      deliveryAddress: parseNullableText(formData.get("deliveryAddress")),
    },
  });

  const checkoutUrl = (data as { checkoutUrl?: string; paymentUrl?: string; url?: string } | null)?.checkoutUrl
    ?? (data as { paymentUrl?: string } | null)?.paymentUrl
    ?? (data as { url?: string } | null)?.url;

  if (error || !checkoutUrl) {
    throw new Error("Unable to start stationery checkout.", { cause: error });
  }

  redirect(checkoutUrl);
}

export async function payExistingStationeryRequest(formData: FormData) {
  const { supabase } = await requireVendorSession("/vendor/profile/stationery");
  const requestId = requireId(formData, "requestId");
  const { data: sessionResult } = await supabase.auth.getSession();
  const accessToken = sessionResult.session?.access_token;
  const { data, error } = await supabase.functions.invoke("create-payfast-stationery-checkout", {
    headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
    body: { requestId },
  });

  const checkoutUrl =
    (data as { checkoutUrl?: string; paymentUrl?: string; url?: string } | null)?.checkoutUrl ??
    (data as { paymentUrl?: string } | null)?.paymentUrl ??
    (data as { url?: string } | null)?.url;

  if (error || !checkoutUrl) {
    throw new Error("Unable to restart stationery checkout.", { cause: error });
  }

  redirect(checkoutUrl);
}

export async function sendVendorMessage(formData: FormData) {
  const { user } = await requireVendorSession("/vendor/messages");
  const threadId = requireId(formData, "threadId");
  const body = parseRequiredText(formData.get("body"));
  const admin = createAdminClient();
  const { data: thread } = await admin
    .from("chat_threads")
    .select("id")
    .eq("id", threadId)
    .eq("vendor_id", user.id)
    .maybeSingle();
  if (!thread) {
    notFound();
  }

  const { data: message, error } = await admin
    .from("chat_messages")
    .insert({
      thread_id: threadId,
      sender_id: user.id,
      body,
      message_type: "text",
    })
    .select("id")
    .single();
  if (error) {
    throw new Error("Unable to send message.", { cause: error });
  }

  if (message?.id) {
    await sendChatMessagePushNotifications([message.id]);
  }

  await admin.from("chat_thread_reads").upsert(
    {
      thread_id: threadId,
      participant_id: user.id,
      last_read_at: new Date().toISOString(),
    },
    { onConflict: "thread_id,participant_id" },
  );

  revalidatePath("/vendor/messages");
  revalidatePath(`/vendor/messages/${threadId}`);
}

export async function createVendorPost(formData: FormData) {
  const { shop, user } = await requireVendorShop("/vendor/profile/posts/new");
  const uploaded = await getUploadedUrls(formData, "mediaFiles", "shop-assets", user.id);
  const mediaUrls = [...parseImageUrls(formData, "mediaUrls"), ...uploaded];
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("shop_posts")
    .insert({
      shop_id: shop.id,
      caption: parseRequiredText(formData.get("caption")),
      media_urls: mediaUrls,
      is_published: isTruthy(formData.get("isPublished")),
    })
    .select("id")
    .single();

  if (error || !data) {
    throw new Error("Unable to create post.", { cause: error });
  }

  revalidatePath("/vendor/profile/posts");
  redirect(`/vendor/profile/posts/${data.id}`);
}

export async function updateVendorPost(formData: FormData) {
  const { shop, user } = await requireVendorShop("/vendor/profile/posts");
  const postId = requireId(formData, "postId");
  const post = await getVendorShopPost(shop.id, postId);
  if (!post) {
    notFound();
  }

  const uploaded = await getUploadedUrls(formData, "mediaFiles", "shop-assets", user.id);
  const mediaUrls = [...parseImageUrls(formData, "mediaUrls"), ...uploaded];
  const admin = createAdminClient();
  const { error } = await admin
    .from("shop_posts")
    .update({
      caption: parseRequiredText(formData.get("caption")),
      media_urls: mediaUrls,
      is_published: isTruthy(formData.get("isPublished")),
    })
    .eq("id", postId)
    .eq("shop_id", shop.id);

  if (error) {
    throw new Error("Unable to update post.", { cause: error });
  }

  revalidatePath("/vendor/profile/posts");
  revalidatePath(`/vendor/profile/posts/${postId}`);
}

export async function deleteVendorPost(formData: FormData) {
  const { shop } = await requireVendorShop("/vendor/profile/posts");
  const postId = requireId(formData, "postId");
  const admin = createAdminClient();
  const { error } = await admin.from("shop_posts").delete().eq("id", postId).eq("shop_id", shop.id);

  if (error) {
    throw new Error("Unable to delete post.", { cause: error });
  }

  revalidatePath("/vendor/profile/posts");
  redirect("/vendor/profile/posts");
}

