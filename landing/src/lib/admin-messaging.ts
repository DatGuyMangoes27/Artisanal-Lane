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

export type AdminMessagingTargetShop = ShopRef;

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
  admin_last_read_message_id: string | null;
  admin_last_read_at: string | null;
  has_unread_vendor_messages: boolean;
  unread_vendor_message_count: number;
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

type AdminShopThreadRow = Omit<
  AdminShopThread,
  "shop" | "vendor" | "admin" | "has_unread_vendor_messages" | "unread_vendor_message_count"
>;

type ChatMessageReadRow = {
  id: string;
  thread_id: string;
  sender_id: string | null;
  created_at: string;
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

export async function listActiveAdminMessagingShops(): Promise<AdminMessagingTargetShop[]> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("shops")
    .select("id, name, vendor_id, logo_url")
    .eq("is_active", true)
    .order("name", { ascending: true });

  if (error) {
    throw new Error(error.message);
  }

  return (data ?? []).filter((shop): shop is AdminMessagingTargetShop =>
    typeof shop.id === "string" &&
    typeof shop.name === "string" &&
    typeof shop.vendor_id === "string" &&
    shop.vendor_id.length > 0
  );
}

/**
 * Fetch every admin<->shop conversation the admin team has ever started.
 * Sorted by chats needing admin attention, then newest activity.
 */
export async function listAdminShopThreads(): Promise<AdminShopThread[]> {
  const admin = createAdminClient();
  const { data } = await admin
    .from("chat_threads")
    .select(
      "id, shop_id, vendor_id, buyer_id, kind, last_message_preview, last_message_type, last_message_sender_id, last_message_at, admin_last_read_message_id, admin_last_read_at, created_at, updated_at",
    )
    .eq("kind", "admin_vendor")
    .order("last_message_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false });

  const rows = (data ?? []) as AdminShopThreadRow[];
  const unreadCounts = await getUnreadVendorMessageCounts(rows);
  const [shops, profiles] = await Promise.all([
    getShopsMap(rows.map((row) => row.shop_id)),
    getProfilesMap(rows.flatMap((row) => [row.vendor_id, row.buyer_id])),
  ]);

  return rows
    .map((row) => ({
      ...row,
      has_unread_vendor_messages: isUnreadForAdmin(row),
      unread_vendor_message_count: unreadCounts.get(row.id) ?? 0,
      shop: shops.get(row.shop_id) ?? null,
      vendor: profiles.get(row.vendor_id) ?? null,
      admin: profiles.get(row.buyer_id) ?? null,
    }))
    .sort((left, right) => {
      if (left.has_unread_vendor_messages !== right.has_unread_vendor_messages) {
        return left.has_unread_vendor_messages ? -1 : 1;
      }

      const leftTime = Date.parse(left.last_message_at ?? left.created_at);
      const rightTime = Date.parse(right.last_message_at ?? right.created_at);
      return rightTime - leftTime;
    });
}

export async function countUnreadAdminShopThreads(): Promise<number> {
  const threads = await listAdminShopThreads();
  return threads.filter((thread) => thread.has_unread_vendor_messages).length;
}

/**
 * Fetch (or create) the admin<->shop thread for a specific shop.
 * The admin team shares one conversation per shop.
 */
export async function getOrCreateAdminShopThread(
  shopId: string,
  adminUserId: string,
): Promise<AdminShopThread | null> {
  const admin = createAdminClient();

  const existing = await admin
    .from("chat_threads")
    .select(
      "id, shop_id, vendor_id, buyer_id, kind, last_message_preview, last_message_type, last_message_sender_id, last_message_at, admin_last_read_message_id, admin_last_read_at, created_at, updated_at",
    )
    .eq("shop_id", shopId)
    .eq("kind", "admin_vendor")
    .order("updated_at", { ascending: false });

  const existingRow = ((existing.data ?? []) as AdminShopThreadRow[]).sort(
    (left, right) => {
      if (isUnreadForAdmin(left) !== isUnreadForAdmin(right)) {
        return isUnreadForAdmin(left) ? -1 : 1;
      }

      return Date.parse(right.updated_at) - Date.parse(left.updated_at);
    },
  )[0];

  if (existingRow) {
    return hydrateThread(existingRow);
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
      "id, shop_id, vendor_id, buyer_id, kind, last_message_preview, last_message_type, last_message_sender_id, last_message_at, admin_last_read_message_id, admin_last_read_at, created_at, updated_at",
    )
    .maybeSingle();

  if (insert.error || !insert.data) {
    throw new Error(
      insert.error?.message ?? "Unable to create admin chat thread.",
    );
  }

  return hydrateThread(insert.data as AdminShopThreadRow);
}

/**
 * Applicant chat threads carry kind 'admin_applicant': buyer_id is the
 * applicant (the thread shows up in their buyer inbox) and vendor_id is the
 * admin. Applicants have no shop yet, so shop_id stays null.
 */
export async function getOrCreateAdminApplicantThread(
  applicantUserId: string,
  adminUserId: string,
): Promise<{ id: string } | null> {
  const admin = createAdminClient();

  const existing = await admin
    .from("chat_threads")
    .select("id")
    .eq("buyer_id", applicantUserId)
    .eq("kind", "admin_applicant")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existing.data) {
    return { id: String(existing.data.id) };
  }

  const profileLookup = await admin
    .from("profiles")
    .select("id")
    .eq("id", applicantUserId)
    .maybeSingle();

  if (!profileLookup.data) {
    return null;
  }

  const insert = await admin
    .from("chat_threads")
    .insert({
      shop_id: null,
      buyer_id: applicantUserId,
      vendor_id: adminUserId,
      kind: "admin_applicant",
    })
    .select("id")
    .maybeSingle();

  if (insert.error || !insert.data) {
    throw new Error(
      insert.error?.message ?? "Unable to create applicant chat thread.",
    );
  }

  return { id: String(insert.data.id) };
}

export async function markAdminApplicantThreadRead(threadId: string) {
  const admin = createAdminClient();
  const threadLookup = await admin
    .from("chat_threads")
    .select("id")
    .eq("id", threadId)
    .eq("kind", "admin_applicant")
    .maybeSingle();

  if (!threadLookup.data) {
    return;
  }

  const latestMessage = await admin
    .from("chat_messages")
    .select("id, created_at")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  await admin
    .from("chat_threads")
    .update({
      admin_last_read_message_id: latestMessage.data?.id ?? null,
      admin_last_read_at: latestMessage.data?.created_at ?? new Date().toISOString(),
    })
    .eq("id", threadId)
    .eq("kind", "admin_applicant");
}

async function hydrateThread(
  row: AdminShopThreadRow,
): Promise<AdminShopThread> {
  const [shops, profiles] = await Promise.all([
    getShopsMap([row.shop_id]),
    getProfilesMap([row.vendor_id, row.buyer_id]),
  ]);

  return {
    ...row,
    has_unread_vendor_messages: isUnreadForAdmin(row),
    unread_vendor_message_count: isUnreadForAdmin(row) ? 1 : 0,
    shop: shops.get(row.shop_id) ?? null,
    vendor: profiles.get(row.vendor_id) ?? null,
    admin: profiles.get(row.buyer_id) ?? null,
  };
}

function isUnreadForAdmin(row: AdminShopThreadRow) {
  if (!row.last_message_at || row.last_message_sender_id !== row.vendor_id) {
    return false;
  }

  if (!row.admin_last_read_at) {
    return true;
  }

  return Date.parse(row.last_message_at) > Date.parse(row.admin_last_read_at);
}

async function getUnreadVendorMessageCounts(rows: AdminShopThreadRow[]) {
  const unreadRows = rows.filter(isUnreadForAdmin);
  if (unreadRows.length === 0) {
    return new Map<string, number>();
  }

  const unreadRowsById = new Map(unreadRows.map((row) => [row.id, row]));
  const admin = createAdminClient();
  const { data } = await admin
    .from("chat_messages")
    .select("id, thread_id, sender_id, created_at")
    .in("thread_id", unreadRows.map((row) => row.id));

  const counts = new Map<string, number>();
  for (const message of (data ?? []) as ChatMessageReadRow[]) {
    const thread = unreadRowsById.get(message.thread_id);
    if (!thread || message.sender_id !== thread.vendor_id) {
      continue;
    }

    if (
      thread.admin_last_read_at &&
      Date.parse(message.created_at) <= Date.parse(thread.admin_last_read_at)
    ) {
      continue;
    }

    counts.set(message.thread_id, (counts.get(message.thread_id) ?? 0) + 1);
  }

  return counts;
}

export async function markAdminShopThreadRead(threadId: string) {
  const admin = createAdminClient();
  const threadLookup = await admin
    .from("chat_threads")
    .select("id")
    .eq("id", threadId)
    .eq("kind", "admin_vendor")
    .maybeSingle();

  if (!threadLookup.data) {
    return;
  }

  const latestMessage = await admin
    .from("chat_messages")
    .select("id, created_at")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  await admin
    .from("chat_threads")
    .update({
      admin_last_read_message_id: latestMessage.data?.id ?? null,
      admin_last_read_at: latestMessage.data?.created_at ?? new Date().toISOString(),
    })
    .eq("id", threadId)
    .eq("kind", "admin_vendor");
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
