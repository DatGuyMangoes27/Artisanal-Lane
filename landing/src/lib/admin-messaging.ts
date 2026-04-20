import "server-only";

import { createAdminClient } from "@/lib/supabase/admin";

type ProfileRef = {
  id: string;
  display_name: string | null;
  email: string | null;
  avatar_url: string | null;
};

type ShopRef = {
  id: string;
  name: string;
  vendor_id: string | null;
  logo_url: string | null;
};

export type AdminShopThread = {
  id: string;
  shop_id: string;
  vendor_id: string;
  buyer_id: string;
  kind: string;
  last_message_preview: string | null;
  last_message_type: string;
  last_message_sender_id: string | null;
  last_message_at: string | null;
  created_at: string;
  updated_at: string;
  shop: ShopRef | null;
  vendor: ProfileRef | null;
  admin: ProfileRef | null;
};

export type AdminShopMessage = {
  id: string;
  thread_id: string;
  sender_id: string;
  body: string | null;
  message_type: string;
  attachment_url: string | null;
  attachment_path: string | null;
  attachment_name: string | null;
  attachment_mime: string | null;
  attachment_size_bytes: number | null;
  created_at: string;
  sender: ProfileRef | null;
};

async function getProfilesMap(ids: string[]) {
  const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
  if (uniqueIds.length === 0) {
    return new Map<string, ProfileRef>();
  }

  const admin = createAdminClient();
  const { data } = await admin
    .from("profiles")
    .select("id, display_name, email, avatar_url")
    .in("id", uniqueIds);

  return new Map(
    (data ?? []).map((profile) => [profile.id, profile as ProfileRef]),
  );
}

async function getShopsMap(ids: string[]) {
  const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
  if (uniqueIds.length === 0) {
    return new Map<string, ShopRef>();
  }

  const admin = createAdminClient();
  const { data } = await admin
    .from("shops")
    .select("id, name, vendor_id, logo_url")
    .in("id", uniqueIds);

  return new Map(
    (data ?? []).map((shop) => [shop.id, shop as ShopRef]),
  );
}

/**
 * Fetch every admin<->shop conversation the admin team has ever started.
 * Sorted newest-activity first.
 */
export async function listAdminShopThreads(): Promise<AdminShopThread[]> {
  const admin = createAdminClient();
  const { data } = await admin
    .from("chat_threads")
    .select(
      "id, shop_id, vendor_id, buyer_id, kind, last_message_preview, last_message_type, last_message_sender_id, last_message_at, created_at, updated_at",
    )
    .eq("kind", "admin_vendor")
    .order("last_message_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false });

  const rows = (data ?? []) as Omit<AdminShopThread, "shop" | "vendor" | "admin">[];
  const [shops, profiles] = await Promise.all([
    getShopsMap(rows.map((row) => row.shop_id)),
    getProfilesMap(rows.flatMap((row) => [row.vendor_id, row.buyer_id])),
  ]);

  return rows.map((row) => ({
    ...row,
    shop: shops.get(row.shop_id) ?? null,
    vendor: profiles.get(row.vendor_id) ?? null,
    admin: profiles.get(row.buyer_id) ?? null,
  }));
}

/**
 * Fetch (or create) the admin<->shop thread for a specific shop + admin.
 * Every admin keeps their own thread with every shop, so we key on both.
 */
export async function getOrCreateAdminShopThread(
  shopId: string,
  adminUserId: string,
): Promise<AdminShopThread | null> {
  const admin = createAdminClient();

  const existing = await admin
    .from("chat_threads")
    .select(
      "id, shop_id, vendor_id, buyer_id, kind, last_message_preview, last_message_type, last_message_sender_id, last_message_at, created_at, updated_at",
    )
    .eq("shop_id", shopId)
    .eq("buyer_id", adminUserId)
    .eq("kind", "admin_vendor")
    .maybeSingle();

  if (existing.data) {
    return hydrateThread(existing.data as Omit<AdminShopThread, "shop" | "vendor" | "admin">);
  }

  const shopLookup = await admin
    .from("shops")
    .select("id, name, vendor_id, logo_url")
    .eq("id", shopId)
    .maybeSingle();

  if (!shopLookup.data || !shopLookup.data.vendor_id) {
    return null;
  }

  const insert = await admin
    .from("chat_threads")
    .insert({
      shop_id: shopId,
      buyer_id: adminUserId,
      vendor_id: shopLookup.data.vendor_id,
      kind: "admin_vendor",
    })
    .select(
      "id, shop_id, vendor_id, buyer_id, kind, last_message_preview, last_message_type, last_message_sender_id, last_message_at, created_at, updated_at",
    )
    .maybeSingle();

  if (insert.error || !insert.data) {
    throw new Error(
      insert.error?.message ?? "Unable to create admin chat thread.",
    );
  }

  return hydrateThread(insert.data as Omit<AdminShopThread, "shop" | "vendor" | "admin">);
}

async function hydrateThread(
  row: Omit<AdminShopThread, "shop" | "vendor" | "admin">,
): Promise<AdminShopThread> {
  const [shops, profiles] = await Promise.all([
    getShopsMap([row.shop_id]),
    getProfilesMap([row.vendor_id, row.buyer_id]),
  ]);

  return {
    ...row,
    shop: shops.get(row.shop_id) ?? null,
    vendor: profiles.get(row.vendor_id) ?? null,
    admin: profiles.get(row.buyer_id) ?? null,
  };
}

export async function getAdminShopThreadMessages(
  threadId: string,
): Promise<AdminShopMessage[]> {
  const admin = createAdminClient();
  const { data } = await admin
    .from("chat_messages")
    .select(
      "id, thread_id, sender_id, body, message_type, attachment_url, attachment_path, attachment_name, attachment_mime, attachment_size_bytes, created_at",
    )
    .eq("thread_id", threadId)
    .order("created_at", { ascending: true });

  const rows = (data ?? []) as Omit<AdminShopMessage, "sender">[];
  const profiles = await getProfilesMap(rows.map((row) => row.sender_id));

  const attachmentIds = rows.filter(
    (row) => row.attachment_path && !row.attachment_url,
  );

  const signedUrls = await Promise.all(
    attachmentIds.map(async (row) => {
      const { data: signed } = await admin.storage
        .from("chat-attachments")
        .createSignedUrl(row.attachment_path!, 60 * 60);
      return [row.id, signed?.signedUrl ?? null] as const;
    }),
  );
  const signedMap = new Map(signedUrls);

  return rows.map((row) => ({
    ...row,
    attachment_url: row.attachment_url ?? signedMap.get(row.id) ?? null,
    sender: profiles.get(row.sender_id) ?? null,
  }));
}

/**
 * Minimal shop lookup for the admin chat header.
 */
export async function getShopForAdminChat(shopId: string) {
  const admin = createAdminClient();
  const { data } = await admin
    .from("shops")
    .select("id, name, vendor_id, logo_url, location")
    .eq("id", shopId)
    .maybeSingle();

  if (!data?.vendor_id) {
    return null;
  }

  const profiles = await getProfilesMap([data.vendor_id]);
  return {
    ...data,
    vendor: profiles.get(data.vendor_id) ?? null,
  };
}
