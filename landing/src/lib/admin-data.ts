import "server-only";

import { createAdminClient } from "@/lib/supabase/admin";

type ProfileRecord = {
  id: string;
  display_name: string | null;
  email: string | null;
  role: string;
};

type ShopRecord = {
  id: string;
  name: string;
  vendor_id: string | null;
  location?: string | null;
  logo_url?: string | null;
  is_active?: boolean;
  is_offline?: boolean;
  is_spotlight?: boolean;
  spotlighted_at?: string | null;
  back_to_work_date?: string | null;
  created_at?: string;
};

type CategoryRecord = {
  id: string;
  name: string;
};

type OrderRecord = {
  id: string;
  buyer_id: string | null;
  shop_id: string | null;
  status: string;
  total: number;
  shipping_cost: number | null;
  shipping_method: string | null;
  tracking_number: string | null;
  shipped_at: string | null;
  received_at: string | null;
  created_at: string;
};

type VendorApplicationRecord = {
  id: string;
  user_id: string | null;
  applicant_user_id_snapshot: string | null;
  applicant_display_name_snapshot: string | null;
  applicant_email_snapshot: string | null;
  applicant_account_deleted_at: string | null;
  superseded_by_application_id: string | null;
  superseded_at: string | null;
  business_name: string;
  motivation: string | null;
  portfolio_url: string | null;
  proof_image_urls: string[] | null;
  location: string | null;
  status: string;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
  delivery_info?: string | null;
  turnaround_time?: string | null;
};

type ProductRecord = {
  id: string;
  shop_id: string | null;
  category_id: string | null;
  title: string;
  price: number;
  stock_qty: number;
  images: string[] | null;
  is_published: boolean;
  is_featured: boolean;
  featured_at: string | null;
  archived_at: string | null;
  created_at: string;
};

type ShopPostRecord = {
  id: string;
  shop_id: string;
  caption: string;
  media_urls: string[] | null;
  is_published: boolean;
  created_at: string;
};

type DisputeRecord = {
  id: string;
  order_id: string;
  raised_by: string | null;
  reason: string;
  status: string;
  resolution: string | null;
  created_at: string;
  resolved_at: string | null;
};

type DisputeConversationRecord = {
  id: string;
  dispute_id: string;
  order_id: string;
  buyer_id: string;
  seller_id: string;
  last_message_preview: string | null;
  last_message_at: string | null;
};

type DisputeConversationMessageRecord = {
  id: string;
  conversation_id: string;
  sender_id: string | null;
  body: string | null;
  message_type: string;
  attachment_name: string | null;
  attachment_path: string | null;
  attachment_mime: string | null;
  attachment_size_bytes: number | null;
  attachment_url: string | null;
  created_at: string;
};

type ShopNoteRecord = {
  id: string;
  shop_id: string;
  note: string;
  created_by: string | null;
  created_at: string;
};

type VendorPayoutProfileRecord = {
  vendor_id: string;
  verification_status: string;
  status_notes: string | null;
  reviewed_at: string | null;
};

type StationeryRequestRecord = {
  id: string;
  shop_id: string;
  vendor_id: string;
  items: Array<{ key?: string; name?: string; quantity?: number }> | null;
  notes: string | null;
  delivery_address: string | null;
  status: string;
  amount: number | null;
  currency: string | null;
  checkout_reference: string | null;
  payment_reference: string | null;
  payfast_payment_id: string | null;
  payfast_email: string | null;
  status_reason: string | null;
  admin_notes: string | null;
  tracking_number: string | null;
  courier_name: string | null;
  fulfilled_by: string | null;
  fulfilled_at: string | null;
  paid_at: string | null;
  created_at: string;
  updated_at: string;
};

type ProductListOptions = {
  query?: string;
  status?: string;
  shop?: string;
  sort?: string;
  page?: number;
  pageSize?: number;
};

type ShopListOptions = {
  query?: string;
  status?: string;
  availability?: string;
  sort?: string;
};

type OrderListOptions = {
  query?: string;
  status?: string;
  shipping?: string;
  sort?: string;
};

type StationeryRequestListOptions = {
  query?: string;
  status?: string;
  sort?: string;
};

function parseStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.map((item) => String(item));
}

function normalizeQuery(value: string | undefined) {
  return value?.trim().toLowerCase() ?? "";
}

function sanitizePostgrestSearch(value: string | undefined) {
  return value?.trim().replace(/[,()%]/g, " ").replace(/\s+/g, " ").trim() ?? "";
}

const disputeAttachmentBucket = "dispute-attachments";

async function withSignedDisputeAttachmentUrls(
  admin: ReturnType<typeof createAdminClient>,
  messages: DisputeConversationMessageRecord[],
) {
  const signedUrls = await Promise.all(
    messages.map(async (message) => {
      if (message.attachment_url || !message.attachment_path) {
        return [message.id, message.attachment_url] as const;
      }

      const { data, error } = await admin.storage
        .from(disputeAttachmentBucket)
        .createSignedUrl(message.attachment_path, 60 * 60);

      if (error) {
        return [message.id, null] as const;
      }

      return [message.id, data.signedUrl] as const;
    }),
  );

  const signedUrlMap = new Map(signedUrls);
  return messages.map((message) => ({
    ...message,
    attachment_url: signedUrlMap.get(message.id) ?? message.attachment_url,
  }));
}

async function getProfilesMap(ids: Array<string | null | undefined>) {
  const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
  if (uniqueIds.length === 0) {
    return new Map<string, ProfileRecord>();
  }

  const admin = createAdminClient();
  const { data } = await admin
    .from("profiles")
    .select("id, display_name, email, role")
    .in("id", uniqueIds);

  return new Map((data ?? []).map((profile) => [profile.id, profile]));
}

async function getShopsMap(ids: string[]) {
  const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
  if (uniqueIds.length === 0) {
    return new Map<string, ShopRecord>();
  }

  const admin = createAdminClient();
  const { data } = await admin
    .from("shops")
    .select("id, name, vendor_id")
    .in("id", uniqueIds);

  return new Map((data ?? []).map((shop) => [shop.id, shop]));
}

async function getCategoriesMap(ids: string[]) {
  const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
  if (uniqueIds.length === 0) {
    return new Map<string, CategoryRecord>();
  }

  const admin = createAdminClient();
  const { data } = await admin
    .from("categories")
    .select("id, name")
    .in("id", uniqueIds);

  return new Map((data ?? []).map((category) => [category.id, category]));
}

async function getVendorPayoutProfilesMap(vendorIds: string[]) {
  const uniqueIds = Array.from(new Set(vendorIds.filter(Boolean)));
  if (uniqueIds.length === 0) {
    return new Map<string, VendorPayoutProfileRecord>();
  }

  const admin = createAdminClient();
  const { data } = await admin
    .from("vendor_payout_profiles")
    .select("vendor_id, verification_status, status_notes, reviewed_at")
    .in("vendor_id", uniqueIds);

  return new Map((data ?? []).map((profile) => [profile.vendor_id, profile]));
}

export async function getDashboardStats() {
  const admin = createAdminClient();

  const [
    { count: ordersCount },
    { count: pendingApplications },
    { count: openDisputes },
    { count: activeShops },
    { count: pendingStationeryRequests },
    escrowResult,
  ] = await Promise.all([
    admin.from("orders").select("id", { count: "exact", head: true }),
    admin
      .from("vendor_applications")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
    admin
      .from("disputes")
      .select("id", { count: "exact", head: true })
      .in("status", ["open", "investigating"]),
    admin
      .from("shops")
      .select("id", { count: "exact", head: true })
      .eq("is_active", true),
    admin
      .from("stationery_requests")
      .select("id", { count: "exact", head: true })
      .in("status", ["awaiting_payment", "paid", "processing"]),
    admin.from("escrow_transactions").select("amount, status, platform_fee"),
  ]);

  const escrowRows = escrowResult.data ?? [];
  const totalRevenue = escrowRows.reduce(
    (sum, row) => sum + Number(row.amount ?? 0),
    0,
  );
  const releasedRevenue = escrowRows
    .filter((row) => row.status === "released")
    .reduce((sum, row) => sum + Number(row.amount ?? 0), 0);

  return {
    ordersCount: ordersCount ?? 0,
    pendingApplications: pendingApplications ?? 0,
    openDisputes: openDisputes ?? 0,
    activeShops: activeShops ?? 0,
    pendingStationeryRequests: pendingStationeryRequests ?? 0,
    totalRevenue,
    releasedRevenue,
  };
}

export async function listVendorApplications() {
  const admin = createAdminClient();
  const { data } = await admin
    .from("vendor_applications")
    .select(
      "id, user_id, applicant_user_id_snapshot, applicant_display_name_snapshot, applicant_email_snapshot, applicant_account_deleted_at, superseded_by_application_id, superseded_at, business_name, motivation, portfolio_url, proof_image_urls, location, status, reviewed_by, reviewed_at, created_at, delivery_info, turnaround_time",
    )
    .is("superseded_at", null)
    .order("created_at", { ascending: false })
    .limit(50);

  const applications = (data ?? []) as VendorApplicationRecord[];
  const profiles = await getProfilesMap(
    applications.flatMap((row) => [row.user_id, row.reviewed_by ?? ""]),
  );

  return applications.map((application) => ({
    ...application,
    proof_image_urls: parseStringArray(application.proof_image_urls),
    applicant: application.user_id ? profiles.get(application.user_id) ?? null : null,
    reviewer: application.reviewed_by
      ? profiles.get(application.reviewed_by) ?? null
      : null,
  }));
}

export type AdminProductPage = {
  items: Array<
    ProductRecord & {
      images: string[];
      shop: ShopRecord | null;
      category: CategoryRecord | null;
    }
  >;
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
};

export async function listProducts(
  options: ProductListOptions = {},
): Promise<AdminProductPage> {
  const admin = createAdminClient();
  const requestedPage = Math.max(1, Math.floor(options.page ?? 1));
  const pageSize = Math.min(100, Math.max(1, Math.floor(options.pageSize ?? 20)));
  const searchTerm = sanitizePostgrestSearch(options.query);

  let matchingShopIds: string[] = [];
  let matchingCategoryIds: string[] = [];

  if (searchTerm) {
    const [shopResult, categoryResult] = await Promise.all([
      admin
        .from("shops")
        .select("id")
        .ilike("name", `%${searchTerm}%`)
        .limit(1000),
      admin
        .from("categories")
        .select("id")
        .ilike("name", `%${searchTerm}%`)
        .limit(1000),
    ]);

    if (shopResult.error) {
      throw new Error(`Unable to search product shops: ${shopResult.error.message}`);
    }
    if (categoryResult.error) {
      throw new Error(`Unable to search product categories: ${categoryResult.error.message}`);
    }

    matchingShopIds = (shopResult.data ?? []).map((shop) => shop.id);
    matchingCategoryIds = (categoryResult.data ?? []).map(
      (category) => category.id,
    );
  }

  let selectedShopIds: string[] | null = null;
  if (options.shop) {
    const { data: shopRows, error: shopError } = await admin
      .from("shops")
      .select("id")
      .eq("name", options.shop)
      .limit(1000);

    if (shopError) {
      throw new Error(`Unable to filter product shops: ${shopError.message}`);
    }

    selectedShopIds = (shopRows ?? []).map((shop) => shop.id);
    if (selectedShopIds.length === 0) {
      return {
        items: [],
        total: 0,
        page: 1,
        pageSize,
        totalPages: 1,
      };
    }
  }

  let productQuery = admin
    .from("products")
    .select(
      "id, shop_id, category_id, title, price, stock_qty, images, is_published, is_featured, featured_at, archived_at, created_at",
      { count: "exact" },
    );

  if (options.status === "archived") {
    productQuery = productQuery.not("archived_at", "is", null);
  } else {
    productQuery = productQuery.is("archived_at", null);
  }

  if (options.status === "published") {
    productQuery = productQuery.eq("is_published", true);
  } else if (options.status === "unpublished") {
    productQuery = productQuery.eq("is_published", false);
  }

  if (selectedShopIds) {
    productQuery = productQuery.in("shop_id", selectedShopIds);
  }

  if (searchTerm) {
    const searchFilters = [`title.ilike.%${searchTerm}%`];
    if (matchingShopIds.length > 0) {
      searchFilters.push(`shop_id.in.(${matchingShopIds.join(",")})`);
    }
    if (matchingCategoryIds.length > 0) {
      searchFilters.push(`category_id.in.(${matchingCategoryIds.join(",")})`);
    }
    productQuery = productQuery.or(searchFilters.join(","));
  }

  switch (options.sort) {
    case "featured":
      productQuery = productQuery
        .order("is_featured", { ascending: false })
        .order("created_at", { ascending: false });
      break;
    case "oldest":
      productQuery = productQuery.order("created_at", { ascending: true });
      break;
    case "price-high":
      productQuery = productQuery.order("price", { ascending: false });
      break;
    case "price-low":
      productQuery = productQuery.order("price", { ascending: true });
      break;
    case "stock-high":
      productQuery = productQuery.order("stock_qty", { ascending: false });
      break;
    case "title":
      productQuery = productQuery.order("title", { ascending: true });
      break;
    default:
      productQuery = productQuery.order("created_at", { ascending: false });
  }

  const rangeStart = (requestedPage - 1) * pageSize;
  const { data, error, count } = await productQuery
    .order("id", { ascending: true })
    .range(rangeStart, rangeStart + pageSize - 1);

  if (error) {
    throw new Error(`Unable to load admin products: ${error.message}`);
  }

  const total = count ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  if (total > 0 && requestedPage > totalPages) {
    return listProducts({ ...options, page: totalPages, pageSize });
  }

  const products = (data ?? []) as ProductRecord[];
  const [shops, categories] = await Promise.all([
    getShopsMap(products.map((row) => row.shop_id ?? "")),
    getCategoriesMap(products.map((row) => row.category_id ?? "")),
  ]);

  const items = products.map((product) => ({
    ...product,
    images: parseStringArray(product.images),
    shop: product.shop_id ? shops.get(product.shop_id) ?? null : null,
    category: product.category_id
      ? categories.get(product.category_id) ?? null
      : null,
  }));

  return {
    items,
    total,
    page: requestedPage,
    pageSize,
    totalPages,
  };
}

export async function listShops(options: ShopListOptions = {}) {
  const admin = createAdminClient();
  const { data } = await admin
    .from("shops")
    .select(
      "id, name, vendor_id, location, logo_url, is_active, is_offline, is_spotlight, spotlighted_at, back_to_work_date, created_at",
    )
    .order("created_at", { ascending: false })
    .limit(100);

  const shops = (data ?? []) as ShopRecord[];
  const shopIds = shops.map((shop) => shop.id);

  const [profiles, productsResult, postsResult] = await Promise.all([
    getProfilesMap(shops.map((shop) => shop.vendor_id ?? "")),
    shopIds.length
      ? admin.from("products").select("id, shop_id").in("shop_id", shopIds)
      : Promise.resolve({ data: [] as { id: string; shop_id: string | null }[] }),
    shopIds.length
      ? admin
          .from("shop_posts")
          .select("id, shop_id, is_published")
          .in("shop_id", shopIds)
      : Promise.resolve(
          { data: [] as { id: string; shop_id: string; is_published: boolean }[] },
        ),
  ]);

  const productCounts = new Map<string, number>();
  for (const product of productsResult.data ?? []) {
    if (!product.shop_id) {
      continue;
    }

    productCounts.set(product.shop_id, (productCounts.get(product.shop_id) ?? 0) + 1);
  }

  const publishedPostCounts = new Map<string, number>();
  const totalPostCounts = new Map<string, number>();
  for (const post of postsResult.data ?? []) {
    totalPostCounts.set(post.shop_id, (totalPostCounts.get(post.shop_id) ?? 0) + 1);

    if (post.is_published) {
      publishedPostCounts.set(
        post.shop_id,
        (publishedPostCounts.get(post.shop_id) ?? 0) + 1,
      );
    }
  }

  const rows = shops.map((shop) => ({
    ...shop,
    vendor: shop.vendor_id ? profiles.get(shop.vendor_id) ?? null : null,
    productCount: productCounts.get(shop.id) ?? 0,
    totalPostCount: totalPostCounts.get(shop.id) ?? 0,
    publishedPostCount: publishedPostCounts.get(shop.id) ?? 0,
  }));

  const query = normalizeQuery(options.query);
  const filtered = rows.filter((shop) => {
    if (options.status === "active" && !shop.is_active) {
      return false;
    }
    if (options.status === "suspended" && shop.is_active) {
      return false;
    }
    if (options.availability === "offline" && !shop.is_offline) {
      return false;
    }
    if (options.availability === "online" && shop.is_offline) {
      return false;
    }
    if (!query) {
      return true;
    }

    const haystack = [
      shop.name,
      shop.location ?? "",
      shop.vendor?.display_name ?? "",
      shop.vendor?.email ?? "",
    ]
      .join(" ")
      .toLowerCase();

    return haystack.includes(query);
  });

  filtered.sort((a, b) => {
    switch (options.sort) {
      case "oldest":
        return (a.created_at ?? "").localeCompare(b.created_at ?? "");
      case "name":
        return a.name.localeCompare(b.name);
      case "products-high":
        return b.productCount - a.productCount;
      case "posts-high":
        return b.totalPostCount - a.totalPostCount;
      default:
        if (a.is_spotlight !== b.is_spotlight) {
          return Number(b.is_spotlight) - Number(a.is_spotlight);
        }
        return (b.created_at ?? "").localeCompare(a.created_at ?? "");
    }
  });

  return filtered;
}

export async function getShopDetail(shopId: string) {
  const admin = createAdminClient();
  const { data } = await admin
    .from("shops")
    .select(
      "id, name, vendor_id, bio, brand_story, location, logo_url, cover_image_url, is_active, is_offline, is_spotlight, spotlighted_at, back_to_work_date, created_at, updated_at",
    )
    .eq("id", shopId)
    .maybeSingle();

  if (!data) {
    return null;
  }

  const shop = data as ShopRecord & {
    bio: string | null;
    brand_story: string | null;
    cover_image_url: string | null;
    updated_at: string;
  };

  const [profiles, productsResult, postsResult, notesResult] = await Promise.all([
    getProfilesMap(shop.vendor_id ? [shop.vendor_id] : []),
    admin
      .from("products")
      .select(
        "id, shop_id, category_id, title, price, stock_qty, images, is_published, is_featured, featured_at, created_at",
      )
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false })
      .limit(24),
    admin
      .from("shop_posts")
      .select("id, shop_id, caption, media_urls, is_published, created_at")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false })
      .limit(24),
    admin
      .from("admin_shop_notes")
      .select("id, shop_id, note, created_by, created_at")
      .eq("shop_id", shopId)
      .order("created_at", { ascending: false })
      .limit(20),
  ]);

  const products = ((productsResult.data ?? []) as ProductRecord[]).map((product) => ({
    ...product,
    images: parseStringArray(product.images),
  }));

  const posts = ((postsResult.data ?? []) as ShopPostRecord[]).map((post) => ({
    ...post,
    media_urls: parseStringArray(post.media_urls),
  }));

  const notes = (notesResult.data ?? []) as ShopNoteRecord[];
  const noteAuthors = await getProfilesMap(notes.map((note) => note.created_by ?? ""));

  return {
    ...shop,
    vendor: shop.vendor_id ? profiles.get(shop.vendor_id) ?? null : null,
    products,
    posts,
    notes: notes.map((note) => ({
      ...note,
      author: note.created_by ? noteAuthors.get(note.created_by) ?? null : null,
    })),
  };
}

export async function listOrders(options: OrderListOptions = {}) {
  const admin = createAdminClient();
  const { data } = await admin
    .from("orders")
    .select(
      "id, buyer_id, shop_id, status, total, shipping_cost, shipping_method, tracking_number, shipped_at, received_at, created_at",
    )
    .order("created_at", { ascending: false })
    .limit(100);

  const orders = (data ?? []) as OrderRecord[];
  const [profiles, shops] = await Promise.all([
    getProfilesMap(orders.map((row) => row.buyer_id ?? "")),
    getShopsMap(orders.map((row) => row.shop_id ?? "")),
  ]);
  const payoutProfiles = await getVendorPayoutProfilesMap(
    Array.from(shops.values()).map((shop) => shop.vendor_id ?? ""),
  );

  const rows = orders.map((order) => ({
    ...order,
    buyer: order.buyer_id ? profiles.get(order.buyer_id) ?? null : null,
    shop: order.shop_id ? shops.get(order.shop_id) ?? null : null,
    payout_profile:
      order.shop_id && shops.get(order.shop_id)?.vendor_id
        ? payoutProfiles.get(shops.get(order.shop_id)!.vendor_id ?? "") ?? null
        : null,
    grand_total: Number(order.total ?? 0) + Number(order.shipping_cost ?? 0),
  }));

  const query = normalizeQuery(options.query);
  const filtered = rows.filter((order) => {
    if (options.status && options.status !== "all" && order.status !== options.status) {
      return false;
    }
    if (
      options.shipping &&
      options.shipping !== "all" &&
      (order.shipping_method ?? "unknown") !== options.shipping
    ) {
      return false;
    }
    if (!query) {
      return true;
    }

    const haystack = [
      order.id,
      order.buyer?.display_name ?? "",
      order.buyer?.email ?? "",
      order.shop?.name ?? "",
      order.tracking_number ?? "",
    ]
      .join(" ")
      .toLowerCase();

    return haystack.includes(query);
  });

  filtered.sort((a, b) => {
    switch (options.sort) {
      case "oldest":
        return a.created_at.localeCompare(b.created_at);
      case "total-high":
        return b.grand_total - a.grand_total;
      case "total-low":
        return a.grand_total - b.grand_total;
      case "status":
        return a.status.localeCompare(b.status);
      default:
        return b.created_at.localeCompare(a.created_at);
    }
  });

  return filtered;
}

export async function listDisputes() {
  const admin = createAdminClient();
  const { data } = await admin
    .from("disputes")
    .select("id, order_id, raised_by, reason, status, resolution, created_at, resolved_at")
    .order("created_at", { ascending: false })
    .limit(100);

  const disputes = (data ?? []) as DisputeRecord[];
  const disputeIds = disputes.map((row) => row.id);
  const [profiles, orders, conversations] = await Promise.all([
    getProfilesMap(disputes.map((row) => row.raised_by ?? "")),
    admin
      .from("orders")
      .select(
        "id, buyer_id, shop_id, status, total, shipping_cost, shipping_method, tracking_number, shipped_at, received_at, created_at",
      )
      .in("id", disputes.map((row) => row.order_id)),
    disputeIds.length === 0
      ? Promise.resolve({ data: [] as DisputeConversationRecord[] })
      : admin
          .from("dispute_conversations")
          .select(
            "id, dispute_id, order_id, buyer_id, seller_id, last_message_preview, last_message_at",
          )
          .in("dispute_id", disputeIds),
  ]);

  const ordersMap = new Map<string, OrderRecord>(
    ((orders.data ?? []) as OrderRecord[]).map((order) => [order.id, order]),
  );
  const conversationRows = (conversations.data ?? []) as DisputeConversationRecord[];
  const conversationIds = conversationRows.map((conversation) => conversation.id);
  const [
    participantProfiles,
    messageSenderProfiles,
    messageRowsResult,
  ] = await Promise.all([
    getProfilesMap(
      conversationRows.flatMap((conversation) => [
        conversation.buyer_id,
        conversation.seller_id,
      ]),
    ),
    conversationIds.length === 0
      ? Promise.resolve(new Map<string, ProfileRecord>())
      : admin
          .from("dispute_conversation_messages")
          .select("sender_id")
          .in("conversation_id", conversationIds)
          .then((result) =>
            getProfilesMap(
              ((result.data ?? []) as Array<{ sender_id: string | null }>).map(
                (message) => message.sender_id ?? "",
              ),
            )
          ),
    conversationIds.length === 0
      ? Promise.resolve({ data: [] as DisputeConversationMessageRecord[] })
      : admin
          .from("dispute_conversation_messages")
          .select(
            "id, conversation_id, sender_id, body, message_type, attachment_name, attachment_path, attachment_mime, attachment_size_bytes, attachment_url, created_at",
          )
          .in("conversation_id", conversationIds)
          .order("created_at", { ascending: true }),
  ]);

  const messageRows = await withSignedDisputeAttachmentUrls(
    admin,
    (messageRowsResult.data ?? []) as DisputeConversationMessageRecord[],
  );

  const conversationMap = new Map<string, DisputeConversationRecord>(
    conversationRows.map((conversation) => [conversation.dispute_id, conversation]),
  );
  const messagesByConversation = new Map<string, DisputeConversationMessageRecord[]>();
  for (const message of messageRows) {
    const bucket = messagesByConversation.get(message.conversation_id) ?? [];
    bucket.push(message);
    messagesByConversation.set(message.conversation_id, bucket);
  }
  const shops = await getShopsMap(
    Array.from(ordersMap.values()).map((order) => order.shop_id ?? ""),
  );

  return disputes.map((dispute) => {
    const order = ordersMap.get(dispute.order_id) ?? null;
    const conversation = conversationMap.get(dispute.id) ?? null;
    return {
      ...dispute,
      raisedByProfile: dispute.raised_by
        ? profiles.get(dispute.raised_by) ?? null
        : null,
      order,
      shop: order?.shop_id ? shops.get(order.shop_id) ?? null : null,
      conversation: conversation == null
        ? null
        : {
            ...conversation,
            buyerProfile: participantProfiles.get(conversation.buyer_id) ?? null,
            sellerProfile: participantProfiles.get(conversation.seller_id) ?? null,
            messages: (messagesByConversation.get(conversation.id) ?? []).map((message) => ({
              ...message,
              senderProfile: message.sender_id
                ? messageSenderProfiles.get(message.sender_id) ?? null
                : null,
            })),
          },
    };
  });
}

export async function listStationeryRequests(
  options: StationeryRequestListOptions = {},
) {
  const admin = createAdminClient();
  const { data } = await admin
    .from("stationery_requests")
    .select(
      "id, shop_id, vendor_id, items, notes, delivery_address, status, amount, currency, checkout_reference, payment_reference, payfast_payment_id, payfast_email, status_reason, admin_notes, tracking_number, courier_name, fulfilled_by, fulfilled_at, paid_at, created_at, updated_at",
    )
    .order("created_at", { ascending: false })
    .limit(100);

  const requests = (data ?? []) as StationeryRequestRecord[];
  const [shops, profiles] = await Promise.all([
    getShopsMap(requests.map((request) => request.shop_id)),
    getProfilesMap(
      requests.flatMap((request) => [
        request.vendor_id,
        request.fulfilled_by ?? "",
      ]),
    ),
  ]);

  const rows = requests.map((request) => ({
    ...request,
    items: Array.isArray(request.items) ? request.items : [],
    shop: shops.get(request.shop_id) ?? null,
    vendor: profiles.get(request.vendor_id) ?? null,
    fulfilledByProfile: request.fulfilled_by
      ? profiles.get(request.fulfilled_by) ?? null
      : null,
    totalQuantity: Array.isArray(request.items)
      ? request.items.reduce(
          (sum, item) => sum + Number(item.quantity ?? 0),
          0,
        )
      : 0,
  }));

  const query = normalizeQuery(options.query);
  const filtered = rows.filter((request) => {
    if (options.status && options.status !== "all" && request.status !== options.status) {
      return false;
    }
    if (!query) {
      return true;
    }

    const haystack = [
      request.shop?.name ?? "",
      request.vendor?.display_name ?? "",
      request.vendor?.email ?? "",
      request.delivery_address ?? "",
      request.notes ?? "",
      request.items.map((item) => item.name ?? item.key ?? "").join(" "),
    ]
      .join(" ")
      .toLowerCase();

    return haystack.includes(query);
  });

  filtered.sort((a, b) => {
    switch (options.sort) {
      case "oldest":
        return a.created_at.localeCompare(b.created_at);
      case "status":
        return a.status.localeCompare(b.status);
      case "quantity-high":
        return b.totalQuantity - a.totalQuantity;
      default:
        return b.created_at.localeCompare(a.created_at);
    }
  });

  return filtered;
}

export type AdminLearningResource = {
  id: string;
  type: "podcast" | "video" | "article";
  title: string;
  description: string | null;
  content_url: string;
  thumbnail_url: string | null;
  author: string | null;
  duration_label: string | null;
  is_published: boolean;
  is_featured: boolean;
  sort_order: number;
  created_at: string;
};

export async function listLearningResources(): Promise<AdminLearningResource[]> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("learning_resources")
    .select(
      "id, type, title, description, content_url, thumbnail_url, author, duration_label, is_published, is_featured, sort_order, created_at",
    )
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false });

  if (error || !data) {
    return [];
  }

  return data.map((row) => ({
    id: String(row.id),
    type:
      row.type === "podcast" || row.type === "video"
        ? row.type
        : "article",
    title: String(row.title ?? ""),
    description: row.description ?? null,
    content_url: String(row.content_url ?? ""),
    thumbnail_url: row.thumbnail_url ?? null,
    author: row.author ?? null,
    duration_label: row.duration_label ?? null,
    is_published: row.is_published !== false,
    is_featured: row.is_featured === true,
    sort_order: typeof row.sort_order === "number" ? row.sort_order : 0,
    created_at: String(row.created_at),
  }));
}

export type AdminNotificationRecipient = {
  id: string;
  display_name: string | null;
  email: string | null;
  role: string;
};

export async function searchNotificationRecipients(
  query: string,
): Promise<AdminNotificationRecipient[]> {
  const sanitized = query.trim().replace(/[,()%]/g, " ").trim();
  if (!sanitized) {
    return [];
  }

  const admin = createAdminClient();
  const { data, error } = await admin
    .from("profiles")
    .select("id, display_name, email, role")
    .or(`email.ilike.%${sanitized}%,display_name.ilike.%${sanitized}%`)
    .order("display_name", { ascending: true })
    .limit(20);

  if (error || !data) {
    return [];
  }

  return data.map((row) => ({
    id: String(row.id),
    display_name: row.display_name ?? null,
    email: row.email ?? null,
    role: String(row.role ?? "buyer"),
  }));
}
