import "server-only";

import { redirect } from "next/navigation";

import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

import {
  getVendorSetupStatus,
  isVendorPayoutReady,
  isVendorShopProfileComplete,
  isVendorSubscriptionActive,
} from "./vendor-utils";

type JsonRecord = Record<string, unknown>;

export type VendorProfile = {
  id: string;
  email: string | null;
  displayName: string | null;
  role: string;
};

export type VendorApplication = {
  id: string;
  businessName: string;
  status: string;
  location: string | null;
  createdAt: string;
};

export type VendorShippingOption = {
  key: string;
  enabled: boolean;
  price: number;
  marketName: string | null;
  marketLocation: string | null;
  marketProvince: string | null;
};

export type VendorShop = {
  id: string;
  vendorId: string;
  name: string;
  slug: string | null;
  bio: string | null;
  brandStory: string | null;
  coverImageUrl: string | null;
  logoUrl: string | null;
  location: string | null;
  shippingOptions: VendorShippingOption[];
  isActive: boolean;
  isOffline: boolean;
  backToWorkDate: string | null;
  createdAt: string;
};

export type VendorPayoutProfile = {
  vendorId: string;
  accountHolderName: string | null;
  bankName: string | null;
  accountNumber: string | null;
  branchCode: string | null;
  accountType: string | null;
  registeredPhone: string | null;
  registeredEmail: string | null;
  identityNumber: string | null;
  verificationStatus: string;
  statusNotes: string | null;
  reviewedAt: string | null;
};

export type VendorSubscription = {
  vendorId: string;
  planCode: string;
  status: string;
  checkoutReference: string | null;
  payfastSubscriptionId: string | null;
  currentPeriodEnd: string | null;
  cancelledAt: string | null;
  createdAt: string;
};

export type VendorProductVariant = {
  id: string;
  productId: string;
  displayName: string;
  optionValues: string[];
  price: number;
  compareAtPrice: number | null;
  stockQty: number;
  images: string[];
  isActive: boolean;
  sortOrder: number;
};

export type VendorProduct = {
  id: string;
  shopId: string;
  categoryId: string | null;
  subcategoryId: string | null;
  title: string;
  description: string | null;
  price: number;
  compareAtPrice: number | null;
  stockQty: number;
  images: string[];
  tags: string[];
  careInstructions: string | null;
  shippingOptions: VendorShippingOption[];
  optionGroups: unknown[];
  isPublished: boolean;
  isFeatured: boolean;
  archivedAt: string | null;
  createdAt: string;
  categoryName: string | null;
  subcategoryName: string | null;
  variants: VendorProductVariant[];
};

export type VendorCategory = {
  id: string;
  name: string;
};

export type VendorSubcategory = {
  id: string;
  categoryId: string | null;
  name: string;
};

export type VendorOrderItem = {
  id: string;
  productId: string | null;
  variantId: string | null;
  productTitle: string;
  variantName: string | null;
  image: string | null;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
};

export type VendorOrder = {
  id: string;
  shortId: string;
  buyerId: string | null;
  buyerName: string | null;
  buyerEmail: string | null;
  status: string;
  total: number;
  shippingCost: number;
  shippingMethod: string | null;
  shippingAddress: JsonRecord | null;
  trackingNumber: string | null;
  trackingUrl: string | null;
  paymentState: string | null;
  shippedAt: string | null;
  receivedAt: string | null;
  isGift: boolean;
  giftRecipient: string | null;
  giftMessage: string | null;
  createdAt: string;
  items: VendorOrderItem[];
};

export type VendorMarketEvent = {
  id: string;
  marketName: string;
  location: string;
  eventDate: string;
  startsAt: string | null;
  endsAt: string | null;
  notes: string | null;
  isActive: boolean;
};

export type VendorShopPost = {
  id: string;
  caption: string;
  mediaUrls: string[];
  isPublished: boolean;
  createdAt: string;
};

export type VendorChatThread = {
  id: string;
  buyerId: string;
  buyerName: string | null;
  buyerEmail: string | null;
  lastMessagePreview: string | null;
  lastMessageAt: string | null;
  lastMessageSenderId: string | null;
  lastReadAt: string | null;
  createdAt: string;
};

export type VendorChatMessage = {
  id: string;
  threadId: string;
  senderId: string;
  body: string | null;
  messageType: string;
  attachmentUrl: string | null;
  attachmentName: string | null;
  createdAt: string;
};

export type VendorStationeryRequest = {
  id: string;
  items: Array<{ key?: string; name?: string; quantity?: number }>;
  notes: string | null;
  deliveryAddress: string | null;
  status: string;
  amount: number | null;
  currency: string | null;
  checkoutReference: string | null;
  statusReason: string | null;
  trackingNumber: string | null;
  courierName: string | null;
  paidAt: string | null;
  createdAt: string;
};

export type VendorEarnings = {
  totalSales: number;
  held: number;
  released: number;
  fees: number;
  recentOrders: VendorOrder[];
};

export type VendorSetup = {
  payoutReady: boolean;
  subscriptionActive: boolean;
  canAddProducts: boolean;
  missingSteps: string[];
};

const productSelect = `
  id,
  shop_id,
  category_id,
  subcategory_id,
  title,
  description,
  price,
  compare_at_price,
  stock_qty,
  images,
  tags,
  care_instructions,
  shipping_options,
  option_groups,
  is_published,
  is_featured,
  archived_at,
  created_at,
  categories(name),
  subcategories(name),
  product_variants(id, product_id, display_name, option_values, price, compare_at_price, stock_qty, images, is_active, sort_order)
`;

const orderSelect = `
  id,
  buyer_id,
  status,
  total,
  shipping_cost,
  shipping_method,
  shipping_address,
  tracking_number,
  tracking_url,
  payment_state,
  shipped_at,
  received_at,
  is_gift,
  gift_recipient,
  gift_message,
  created_at,
  buyer:profiles!orders_buyer_id_fkey(display_name, email),
  order_items(id, product_id, variant_id, variant_name, variant_image, quantity, unit_price, products(title, images))
`;

function toRecord(value: unknown): JsonRecord | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonRecord)
    : null;
}

function toStringOrNull(value: unknown) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function toNumber(value: unknown, fallback = 0) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

function toStringArray(value: unknown) {
  return Array.isArray(value) ? value.map(String).filter(Boolean) : [];
}

function toJsonArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function normalizeShippingOptions(value: unknown): VendorShippingOption[] {
  const raw = Array.isArray(value) ? value : [];
  return raw.map((item) => {
    const option = toRecord(item) ?? {};
    return {
      key: toStringOrNull(option.key) ?? "custom",
      enabled: option.enabled !== false,
      price: toNumber(option.price),
      marketName: toStringOrNull(option.marketName ?? option.market_name),
      marketLocation: toStringOrNull(option.marketLocation ?? option.market_location),
      marketProvince: toStringOrNull(option.marketProvince ?? option.market_province),
    };
  });
}

export async function requireVendorSession(redirectTo = "/vendor") {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect(`/login?redirect=${encodeURIComponent(redirectTo)}`);
  }

  const admin = createAdminClient();
  const { data: profile } = await admin
    .from("profiles")
    .select("id, display_name, email, role")
    .eq("id", user.id)
    .maybeSingle();

  const mappedProfile: VendorProfile = {
    id: user.id,
    email: toStringOrNull(profile?.email) ?? user.email ?? null,
    displayName: toStringOrNull(profile?.display_name),
    role: toStringOrNull(profile?.role) ?? "buyer",
  };

  const { data: application } = await admin
    .from("vendor_applications")
    .select("id, business_name, status, location, created_at")
    .or(`user_id.eq.${user.id},applicant_user_id_snapshot.eq.${user.id}`)
    .is("superseded_at", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  return {
    supabase,
    admin,
    user,
    profile: mappedProfile,
    application: application ? mapVendorApplication(application) : null,
    isApprovedVendor: mappedProfile.role === "vendor" || mappedProfile.role === "admin",
  };
}

export async function getVendorShop(vendorId: string): Promise<VendorShop | null> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("shops")
    .select(
      "id, vendor_id, name, slug, bio, brand_story, cover_image_url, logo_url, location, shipping_options, is_active, is_offline, back_to_work_date, created_at",
    )
    .eq("vendor_id", vendorId)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load vendor shop.", { cause: error });
  }

  return data ? mapVendorShop(data as JsonRecord) : null;
}

export async function requireVendorShop(redirectTo = "/vendor") {
  const session = await requireVendorSession(redirectTo);

  if (!session.isApprovedVendor) {
    redirect("/vendor");
  }

  const shop = await getVendorShop(session.user.id);
  if (!shop) {
    redirect("/vendor");
  }

  return { ...session, shop };
}

export async function getVendorPayoutProfile(
  vendorId: string,
): Promise<VendorPayoutProfile | null> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("vendor_payout_profiles")
    .select(
      "vendor_id, account_holder_name, bank_name, account_number, branch_code, account_type, registered_phone, registered_email, identity_number, verification_status, status_notes, reviewed_at",
    )
    .eq("vendor_id", vendorId)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load payout profile.", { cause: error });
  }

  return data ? mapVendorPayoutProfile(data as JsonRecord) : null;
}

export async function getVendorSubscription(
  vendorId: string,
): Promise<VendorSubscription | null> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("vendor_subscriptions")
    .select(
      "vendor_id, plan_code, status, checkout_reference, payfast_subscription_id, current_period_end, cancelled_at, created_at",
    )
    .eq("vendor_id", vendorId)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load subscription.", { cause: error });
  }

  return data ? mapVendorSubscription(data as JsonRecord) : null;
}

export async function getVendorSetup(vendorId: string): Promise<VendorSetup> {
  const [shop, payout, subscription] = await Promise.all([
    getVendorShop(vendorId),
    getVendorPayoutProfile(vendorId),
    getVendorSubscription(vendorId),
  ]);
  const payoutReady = isVendorPayoutReady(payout);
  const subscriptionActive = isVendorSubscriptionActive(subscription);
  const setup = getVendorSetupStatus({
    hasShop: isVendorShopProfileComplete(shop),
    payoutReady,
    subscriptionActive,
  });

  return {
    ...setup,
    payoutReady,
    subscriptionActive,
  };
}

export async function getVendorDashboardData(vendorId: string) {
  const [shop, payout, subscription] = await Promise.all([
    getVendorShop(vendorId),
    getVendorPayoutProfile(vendorId),
    getVendorSubscription(vendorId),
  ]);

  if (!shop) {
    return {
      shop,
      payout,
      subscription,
      setup: {
        ...getVendorSetupStatus({
          hasShop: false,
          payoutReady: false,
          subscriptionActive: false,
        }),
        payoutReady: false,
        subscriptionActive: false,
      },
      productCount: 0,
      orderCount: 0,
      activeOrderCount: 0,
      unreadMessageCount: 0,
      earnings: { totalSales: 0, held: 0, released: 0, fees: 0, recentOrders: [] },
      recentOrders: [],
      posts: [],
      marketEvents: [],
    };
  }

  const admin = createAdminClient();
  const [
    productCountResult,
    orderCountResult,
    activeOrderCountResult,
    unreadThreadsResult,
    earnings,
    recentOrders,
    posts,
    marketEvents,
  ] = await Promise.all([
    admin
      .from("products")
      .select("id", { count: "exact", head: true })
      .eq("shop_id", shop.id)
      .is("archived_at", null),
    admin
      .from("orders")
      .select("id", { count: "exact", head: true })
      .eq("shop_id", shop.id),
    admin
      .from("orders")
      .select("id", { count: "exact", head: true })
      .eq("shop_id", shop.id)
      .in("status", ["pending", "paid", "processing", "shipped", "disputed"]),
    admin
      .from("chat_threads")
      .select("id", { count: "exact", head: true })
      .eq("vendor_id", vendorId)
      .neq("last_message_sender_id", vendorId),
    getVendorEarnings(shop.id),
    listVendorOrders(shop.id, { limit: 5 }),
    listVendorShopPosts(shop.id, 3),
    listVendorMarketEvents(shop.id, 3),
  ]);

  const payoutReady = isVendorPayoutReady(payout);
  const subscriptionActive = isVendorSubscriptionActive(subscription);
  const shopProfileComplete = isVendorShopProfileComplete(shop);
  const setup = getVendorSetupStatus({
    hasShop: shopProfileComplete,
    payoutReady,
    subscriptionActive,
  });

  return {
    shop,
    payout,
    subscription,
    setup: {
      ...setup,
      payoutReady,
      subscriptionActive,
    },
    productCount: productCountResult.count ?? 0,
    orderCount: orderCountResult.count ?? 0,
    activeOrderCount: activeOrderCountResult.count ?? 0,
    unreadMessageCount: unreadThreadsResult.count ?? 0,
    earnings,
    recentOrders,
    posts,
    marketEvents,
  };
}

export async function listVendorProducts(shopId: string): Promise<VendorProduct[]> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("products")
    .select(productSelect)
    .eq("shop_id", shopId)
    .is("archived_at", null)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load products.", { cause: error });
  }

  return ((data ?? []) as JsonRecord[]).map(mapVendorProduct);
}

export async function getVendorProduct(
  shopId: string,
  productId: string,
): Promise<VendorProduct | null> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("products")
    .select(productSelect)
    .eq("shop_id", shopId)
    .eq("id", productId)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load product.", { cause: error });
  }

  return data ? mapVendorProduct(data as JsonRecord) : null;
}

export async function listVendorCategories() {
  const admin = createAdminClient();
  const [categoriesResult, subcategoriesResult] = await Promise.all([
    admin.from("categories").select("id, name").order("name"),
    admin.from("subcategories").select("id, category_id, name").order("name"),
  ]);

  return {
    categories: ((categoriesResult.data ?? []) as JsonRecord[]).map((row) => ({
      id: String(row.id),
      name: String(row.name),
    })),
    subcategories: ((subcategoriesResult.data ?? []) as JsonRecord[]).map((row) => ({
      id: String(row.id),
      categoryId: toStringOrNull(row.category_id),
      name: String(row.name),
    })),
  };
}

export async function listVendorOrders(
  shopId: string,
  options: { status?: string; limit?: number } = {},
): Promise<VendorOrder[]> {
  const admin = createAdminClient();
  let query = admin.from("orders").select(orderSelect).eq("shop_id", shopId);

  if (options.status && options.status !== "all") {
    query = query.eq("status", options.status);
  }

  query = query.order("created_at", { ascending: false });
  if (options.limit) {
    query = query.limit(options.limit);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error("Failed to load orders.", { cause: error });
  }

  return ((data ?? []) as JsonRecord[]).map(mapVendorOrder);
}

export async function getVendorOrder(
  shopId: string,
  orderId: string,
): Promise<VendorOrder | null> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("orders")
    .select(orderSelect)
    .eq("shop_id", shopId)
    .eq("id", orderId)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load order.", { cause: error });
  }

  return data ? mapVendorOrder(data as JsonRecord) : null;
}

export async function listVendorMarketEvents(
  shopId: string,
  limit?: number,
): Promise<VendorMarketEvent[]> {
  const admin = createAdminClient();
  let query = admin
    .from("shop_market_events")
    .select("id, market_name, location, event_date, starts_at, ends_at, notes, is_active")
    .eq("shop_id", shopId)
    .order("event_date", { ascending: true });

  if (limit) {
    query = query.limit(limit);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error("Failed to load market events.", { cause: error });
  }

  return ((data ?? []) as JsonRecord[]).map(mapVendorMarketEvent);
}

export async function listVendorShopPosts(
  shopId: string,
  limit?: number,
): Promise<VendorShopPost[]> {
  const admin = createAdminClient();
  let query = admin
    .from("shop_posts")
    .select("id, caption, media_urls, is_published, created_at")
    .eq("shop_id", shopId)
    .order("created_at", { ascending: false });

  if (limit) {
    query = query.limit(limit);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error("Failed to load shop posts.", { cause: error });
  }

  return ((data ?? []) as JsonRecord[]).map(mapVendorShopPost);
}

export async function getVendorShopPost(
  shopId: string,
  postId: string,
): Promise<VendorShopPost | null> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("shop_posts")
    .select("id, caption, media_urls, is_published, created_at")
    .eq("shop_id", shopId)
    .eq("id", postId)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load shop post.", { cause: error });
  }

  return data ? mapVendorShopPost(data as JsonRecord) : null;
}

export async function listVendorChatThreads(vendorId: string): Promise<VendorChatThread[]> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("chat_threads")
    .select(
      "id, buyer_id, last_message_preview, last_message_sender_id, last_message_at, created_at, buyer:profiles!chat_threads_buyer_id_fkey(display_name, email), chat_thread_reads(participant_id, last_read_at)",
    )
    .eq("vendor_id", vendorId)
    .eq("kind", "buyer_vendor")
    .order("last_message_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load messages.", { cause: error });
  }

  return ((data ?? []) as JsonRecord[]).map((row) => mapVendorChatThread(row, vendorId));
}

export async function getVendorChatThread(
  vendorId: string,
  threadId: string,
): Promise<VendorChatThread | null> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("chat_threads")
    .select(
      "id, buyer_id, last_message_preview, last_message_sender_id, last_message_at, created_at, buyer:profiles!chat_threads_buyer_id_fkey(display_name, email), chat_thread_reads(participant_id, last_read_at)",
    )
    .eq("vendor_id", vendorId)
    .eq("id", threadId)
    .eq("kind", "buyer_vendor")
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load message thread.", { cause: error });
  }

  return data ? mapVendorChatThread(data as JsonRecord, vendorId) : null;
}

export async function listVendorChatMessages(
  threadId: string,
): Promise<VendorChatMessage[]> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("chat_messages")
    .select("id, thread_id, sender_id, body, message_type, attachment_url, attachment_name, created_at")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: true });

  if (error) {
    throw new Error("Failed to load message history.", { cause: error });
  }

  return ((data ?? []) as JsonRecord[]).map((row) => ({
    id: String(row.id),
    threadId: String(row.thread_id),
    senderId: String(row.sender_id),
    body: toStringOrNull(row.body),
    messageType: toStringOrNull(row.message_type) ?? "text",
    attachmentUrl: toStringOrNull(row.attachment_url),
    attachmentName: toStringOrNull(row.attachment_name),
    createdAt: String(row.created_at),
  }));
}

export async function listVendorStationeryRequests(
  vendorId: string,
): Promise<VendorStationeryRequest[]> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("stationery_requests")
    .select(
      "id, items, notes, delivery_address, status, amount, currency, checkout_reference, status_reason, tracking_number, courier_name, paid_at, created_at",
    )
    .eq("vendor_id", vendorId)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load stationery requests.", { cause: error });
  }

  return ((data ?? []) as JsonRecord[]).map((row) => ({
    id: String(row.id),
    items: Array.isArray(row.items) ? row.items : [],
    notes: toStringOrNull(row.notes),
    deliveryAddress: toStringOrNull(row.delivery_address),
    status: toStringOrNull(row.status) ?? "submitted",
    amount: row.amount == null ? null : toNumber(row.amount),
    currency: toStringOrNull(row.currency),
    checkoutReference: toStringOrNull(row.checkout_reference),
    statusReason: toStringOrNull(row.status_reason),
    trackingNumber: toStringOrNull(row.tracking_number),
    courierName: toStringOrNull(row.courier_name),
    paidAt: toStringOrNull(row.paid_at),
    createdAt: String(row.created_at),
  }));
}

export async function getVendorEarnings(shopId: string): Promise<VendorEarnings> {
  const orders = await listVendorOrders(shopId, { limit: 200 });
  const orderIds = orders.map((order) => order.id);

  if (orderIds.length === 0) {
    return { totalSales: 0, held: 0, released: 0, fees: 0, recentOrders: [] };
  }

  const admin = createAdminClient();
  const { data, error } = await admin
    .from("escrow_transactions")
    .select("amount, platform_fee, status")
    .in("order_id", orderIds);

  if (error) {
    throw new Error("Failed to load earnings.", { cause: error });
  }

  const earnings = ((data ?? []) as JsonRecord[]).reduce<{
    totalSales: number;
    held: number;
    released: number;
    fees: number;
  }>(
    (totals, row) => {
      const status = toStringOrNull(row.status);
      if (!["held", "released", "refunded"].includes(status ?? "")) {
        return totals;
      }
      const amount = toNumber(row.amount);
      const fee = toNumber(row.platform_fee);
      totals.totalSales += amount;
      totals.fees += fee;
      if (status === "held") totals.held += amount;
      if (status === "released") totals.released += amount - fee;
      return totals;
    },
    { totalSales: 0, held: 0, released: 0, fees: 0 },
  );

  return {
    ...earnings,
    recentOrders: orders.slice(0, 8),
  };
}

function mapVendorApplication(row: JsonRecord): VendorApplication {
  return {
    id: String(row.id),
    businessName: toStringOrNull(row.business_name) ?? "Application",
    status: toStringOrNull(row.status) ?? "pending",
    location: toStringOrNull(row.location),
    createdAt: String(row.created_at),
  };
}

function mapVendorShop(row: JsonRecord): VendorShop {
  return {
    id: String(row.id),
    vendorId: String(row.vendor_id),
    name: String(row.name),
    slug: toStringOrNull(row.slug),
    bio: toStringOrNull(row.bio),
    brandStory: toStringOrNull(row.brand_story),
    coverImageUrl: toStringOrNull(row.cover_image_url),
    logoUrl: toStringOrNull(row.logo_url),
    location: toStringOrNull(row.location),
    shippingOptions: normalizeShippingOptions(row.shipping_options),
    isActive: row.is_active !== false,
    isOffline: row.is_offline === true,
    backToWorkDate: toStringOrNull(row.back_to_work_date),
    createdAt: String(row.created_at),
  };
}

function mapVendorPayoutProfile(row: JsonRecord): VendorPayoutProfile {
  return {
    vendorId: String(row.vendor_id),
    accountHolderName: toStringOrNull(row.account_holder_name),
    bankName: toStringOrNull(row.bank_name),
    accountNumber: toStringOrNull(row.account_number),
    branchCode: toStringOrNull(row.branch_code),
    accountType: toStringOrNull(row.account_type),
    registeredPhone: toStringOrNull(row.registered_phone),
    registeredEmail: toStringOrNull(row.registered_email),
    identityNumber: toStringOrNull(row.identity_number),
    verificationStatus: toStringOrNull(row.verification_status) ?? "not_started",
    statusNotes: toStringOrNull(row.status_notes),
    reviewedAt: toStringOrNull(row.reviewed_at),
  };
}

function mapVendorSubscription(row: JsonRecord): VendorSubscription {
  return {
    vendorId: String(row.vendor_id),
    planCode: toStringOrNull(row.plan_code) ?? "artisan-monthly",
    status: toStringOrNull(row.status) ?? "inactive",
    checkoutReference: toStringOrNull(row.checkout_reference),
    payfastSubscriptionId: toStringOrNull(row.payfast_subscription_id),
    currentPeriodEnd: toStringOrNull(row.current_period_end),
    cancelledAt: toStringOrNull(row.cancelled_at),
    createdAt: String(row.created_at),
  };
}

function mapVendorProduct(row: JsonRecord): VendorProduct {
  const category = toRecord(row.categories);
  const subcategory = toRecord(row.subcategories);
  const variants = Array.isArray(row.product_variants) ? row.product_variants : [];

  return {
    id: String(row.id),
    shopId: String(row.shop_id),
    categoryId: toStringOrNull(row.category_id),
    subcategoryId: toStringOrNull(row.subcategory_id),
    title: String(row.title),
    description: toStringOrNull(row.description),
    price: toNumber(row.price),
    compareAtPrice: row.compare_at_price == null ? null : toNumber(row.compare_at_price),
    stockQty: Math.trunc(toNumber(row.stock_qty)),
    images: toStringArray(row.images),
    tags: toStringArray(row.tags),
    careInstructions: toStringOrNull(row.care_instructions),
    shippingOptions: normalizeShippingOptions(row.shipping_options),
    optionGroups: toJsonArray(row.option_groups),
    isPublished: row.is_published === true,
    isFeatured: row.is_featured === true,
    archivedAt: toStringOrNull(row.archived_at),
    createdAt: String(row.created_at),
    categoryName: toStringOrNull(category?.name),
    subcategoryName: toStringOrNull(subcategory?.name),
    variants: variants.map((variant) => mapVendorProductVariant(toRecord(variant) ?? {})),
  };
}

function mapVendorProductVariant(row: JsonRecord): VendorProductVariant {
  return {
    id: String(row.id),
    productId: String(row.product_id),
    displayName: toStringOrNull(row.display_name) ?? "Variant",
    optionValues: toStringArray(row.option_values),
    price: toNumber(row.price),
    compareAtPrice: row.compare_at_price == null ? null : toNumber(row.compare_at_price),
    stockQty: Math.trunc(toNumber(row.stock_qty)),
    images: toStringArray(row.images),
    isActive: row.is_active !== false,
    sortOrder: Math.trunc(toNumber(row.sort_order)),
  };
}

function mapVendorOrder(row: JsonRecord): VendorOrder {
  const buyer = toRecord(row.buyer);
  const items = Array.isArray(row.order_items) ? row.order_items : [];
  return {
    id: String(row.id),
    shortId: String(row.id).slice(0, 8).toUpperCase(),
    buyerId: toStringOrNull(row.buyer_id),
    buyerName: toStringOrNull(buyer?.display_name),
    buyerEmail: toStringOrNull(buyer?.email),
    status: toStringOrNull(row.status) ?? "pending",
    total: toNumber(row.total),
    shippingCost: toNumber(row.shipping_cost),
    shippingMethod: toStringOrNull(row.shipping_method),
    shippingAddress: toRecord(row.shipping_address),
    trackingNumber: toStringOrNull(row.tracking_number),
    trackingUrl: toStringOrNull(row.tracking_url),
    paymentState: toStringOrNull(row.payment_state),
    shippedAt: toStringOrNull(row.shipped_at),
    receivedAt: toStringOrNull(row.received_at),
    isGift: row.is_gift === true,
    giftRecipient: toStringOrNull(row.gift_recipient),
    giftMessage: toStringOrNull(row.gift_message),
    createdAt: String(row.created_at),
    items: items.map((item) => mapVendorOrderItem(toRecord(item) ?? {})),
  };
}

function mapVendorOrderItem(row: JsonRecord): VendorOrderItem {
  const product = toRecord(row.products);
  const productImages = toStringArray(product?.images);
  const quantity = Math.trunc(toNumber(row.quantity));
  const unitPrice = toNumber(row.unit_price);
  return {
    id: String(row.id),
    productId: toStringOrNull(row.product_id),
    variantId: toStringOrNull(row.variant_id),
    productTitle: toStringOrNull(product?.title) ?? "Product",
    variantName: toStringOrNull(row.variant_name),
    image: toStringOrNull(row.variant_image) ?? productImages[0] ?? null,
    quantity,
    unitPrice,
    lineTotal: quantity * unitPrice,
  };
}

function mapVendorMarketEvent(row: JsonRecord): VendorMarketEvent {
  return {
    id: String(row.id),
    marketName: String(row.market_name),
    location: String(row.location),
    eventDate: String(row.event_date),
    startsAt: toStringOrNull(row.starts_at),
    endsAt: toStringOrNull(row.ends_at),
    notes: toStringOrNull(row.notes),
    isActive: row.is_active !== false,
  };
}

function mapVendorShopPost(row: JsonRecord): VendorShopPost {
  return {
    id: String(row.id),
    caption: toStringOrNull(row.caption) ?? "",
    mediaUrls: toStringArray(row.media_urls),
    isPublished: row.is_published === true,
    createdAt: String(row.created_at),
  };
}

function mapVendorChatThread(row: JsonRecord, vendorId: string): VendorChatThread {
  const buyer = toRecord(row.buyer);
  const reads = Array.isArray(row.chat_thread_reads) ? row.chat_thread_reads : [];
  const read = reads.map(toRecord).find((entry) => entry?.participant_id === vendorId);
  return {
    id: String(row.id),
    buyerId: String(row.buyer_id),
    buyerName: toStringOrNull(buyer?.display_name),
    buyerEmail: toStringOrNull(buyer?.email),
    lastMessagePreview: toStringOrNull(row.last_message_preview),
    lastMessageAt: toStringOrNull(row.last_message_at),
    lastMessageSenderId: toStringOrNull(row.last_message_sender_id),
    lastReadAt: toStringOrNull(read?.last_read_at),
    createdAt: String(row.created_at),
  };
}
