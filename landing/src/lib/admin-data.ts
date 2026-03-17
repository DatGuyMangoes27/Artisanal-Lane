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
  user_id: string;
  business_name: string;
  motivation: string | null;
  portfolio_url: string | null;
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

type ShopNoteRecord = {
  id: string;
  shop_id: string;
  note: string;
  created_by: string | null;
  created_at: string;
};

type StationeryRequestRecord = {
  id: string;
  shop_id: string;
  vendor_id: string;
  items: Array<{ key?: string; name?: string; quantity?: number }> | null;
  notes: string | null;
  delivery_address: string | null;
  status: string;
  admin_notes: string | null;
  tracking_number: string | null;
  courier_name: string | null;
  fulfilled_by: string | null;
  fulfilled_at: string | null;
  created_at: string;
  updated_at: string;
};

type ProductListOptions = {
  query?: string;
  status?: string;
  shop?: string;
  sort?: string;
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

async function getProfilesMap(ids: string[]) {
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
      .in("status", ["pending", "processing"]),
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
      "id, user_id, business_name, motivation, portfolio_url, location, status, reviewed_by, reviewed_at, created_at, delivery_info, turnaround_time",
    )
    .order("created_at", { ascending: false })
    .limit(50);

  const applications = (data ?? []) as VendorApplicationRecord[];
  const profiles = await getProfilesMap(
    applications.flatMap((row) => [row.user_id, row.reviewed_by ?? ""]),
  );

  return applications.map((application) => ({
    ...application,
    applicant: profiles.get(application.user_id) ?? null,
    reviewer: application.reviewed_by
      ? profiles.get(application.reviewed_by) ?? null
      : null,
  }));
}

export async function listProducts(options: ProductListOptions = {}) {
  const admin = createAdminClient();
  const { data } = await admin
    .from("products")
    .select(
      "id, shop_id, category_id, title, price, stock_qty, images, is_published, is_featured, featured_at, created_at",
    )
    .order("created_at", { ascending: false })
    .limit(100);

  const products = (data ?? []) as ProductRecord[];
  const [shops, categories] = await Promise.all([
    getShopsMap(products.map((row) => row.shop_id ?? "")),
    getCategoriesMap(products.map((row) => row.category_id ?? "")),
  ]);

  const rows = products.map((product) => ({
    ...product,
    images: parseStringArray(product.images),
    shop: product.shop_id ? shops.get(product.shop_id) ?? null : null,
    category: product.category_id
      ? categories.get(product.category_id) ?? null
      : null,
  }));

  const query = normalizeQuery(options.query);
  const filtered = rows.filter((product) => {
    if (options.status === "published" && !product.is_published) {
      return false;
    }
    if (options.status === "unpublished" && product.is_published) {
      return false;
    }
    if (options.shop && product.shop?.name !== options.shop) {
      return false;
    }
    if (!query) {
      return true;
    }

    const haystack = [
      product.title,
      product.shop?.name ?? "",
      product.category?.name ?? "",
    ]
      .join(" ")
      .toLowerCase();

    return haystack.includes(query);
  });

  filtered.sort((a, b) => {
    switch (options.sort) {
      case "featured":
        return Number(b.is_featured) - Number(a.is_featured);
      case "oldest":
        return a.created_at.localeCompare(b.created_at);
      case "price-high":
        return b.price - a.price;
      case "price-low":
        return a.price - b.price;
      case "stock-high":
        return b.stock_qty - a.stock_qty;
      case "title":
        return a.title.localeCompare(b.title);
      default:
        return b.created_at.localeCompare(a.created_at);
    }
  });

  return filtered;
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

  const rows = orders.map((order) => ({
    ...order,
    buyer: order.buyer_id ? profiles.get(order.buyer_id) ?? null : null,
    shop: order.shop_id ? shops.get(order.shop_id) ?? null : null,
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
  const [profiles, orders] = await Promise.all([
    getProfilesMap(disputes.map((row) => row.raised_by ?? "")),
    admin
      .from("orders")
      .select(
        "id, buyer_id, shop_id, status, total, shipping_cost, shipping_method, tracking_number, shipped_at, received_at, created_at",
      )
      .in("id", disputes.map((row) => row.order_id)),
  ]);

  const ordersMap = new Map<string, OrderRecord>(
    ((orders.data ?? []) as OrderRecord[]).map((order) => [order.id, order]),
  );
  const shops = await getShopsMap(
    Array.from(ordersMap.values()).map((order) => order.shop_id ?? ""),
  );

  return disputes.map((dispute) => {
    const order = ordersMap.get(dispute.order_id) ?? null;
    return {
      ...dispute,
      raisedByProfile: dispute.raised_by
        ? profiles.get(dispute.raised_by) ?? null
        : null,
      order,
      shop: order?.shop_id ? shops.get(order.shop_id) ?? null : null,
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
      "id, shop_id, vendor_id, items, notes, delivery_address, status, admin_notes, tracking_number, courier_name, fulfilled_by, fulfilled_at, created_at, updated_at",
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

