import "server-only";

import {
  MODERATION_LOG_PAGE_SIZE,
  MODERATION_PAGE_SIZE,
  type ReportReason,
  type ReportStatus,
  type ReportTargetType,
  firstImageUrl,
  groupReportsByTarget,
  isBannedUntil,
  reportTargetKey,
  type ReportGroup,
} from "@/lib/admin-moderation";
import { createAdminClient } from "@/lib/supabase/admin";

export type ModerationReportRow = {
  id: string;
  reporter_id: string;
  target_type: ReportTargetType;
  target_id: string;
  reason: ReportReason;
  details: string;
  target_text_snapshot: string;
  target_owner_id: string | null;
  target_shop_id: string | null;
  status: ReportStatus;
  resolution_notes: string;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
};

export type ModerationTargetState =
  | { type: "post"; exists: false }
  | {
      type: "post";
      exists: true;
      caption: string;
      imageUrl: string | null;
      hasMedia: boolean;
      removedAt: string | null;
      removedReason: string | null;
    }
  | { type: "comment"; exists: false }
  | { type: "comment"; exists: true; body: string; authorName: string | null }
  | { type: "story"; exists: false }
  | { type: "story"; exists: true; caption: string; expiresAt: string; expired: boolean }
  | { type: "shop"; exists: false }
  | { type: "shop"; exists: true; name: string; isActive: boolean };

export type ModerationReportView = ModerationReportRow & {
  reporter: { name: string | null; email: string | null } | null;
  owner: { name: string | null; email: string | null } | null;
  ownerSuspended: boolean;
  shop: { id: string; name: string; isActive: boolean } | null;
  target: ModerationTargetState;
  /** Open reports (any reporter) that target the same item, including this one when open. */
  group: ReportGroup | null;
  reviewer: string | null;
};

export type ModerationFilters = {
  status: ReportStatus;
  targetType: ReportTargetType | "";
  reason: ReportReason | "";
  page: number;
};

type ProfileLite = { id: string; display_name: string | null; email: string | null };

function uniq(values: Array<string | null | undefined>) {
  return [...new Set(values.filter((value): value is string => Boolean(value)))];
}

export async function countOpenModerationReports() {
  try {
    const admin = createAdminClient();
    const { count } = await admin
      .from("creator_content_reports")
      .select("id", { count: "exact", head: true })
      .eq("status", "open");
    return count ?? 0;
  } catch {
    return 0;
  }
}

export async function getModerationTabCounts(
  filters: Pick<ModerationFilters, "targetType" | "reason">,
) {
  const admin = createAdminClient();
  const entries = await Promise.all(
    (["open", "resolved", "dismissed"] as const).map(async (status) => {
      let query = admin
        .from("creator_content_reports")
        .select("id", { count: "exact", head: true })
        .eq("status", status);
      if (filters.targetType) query = query.eq("target_type", filters.targetType);
      if (filters.reason) query = query.eq("reason", filters.reason);
      const { count } = await query;
      return [status, count ?? 0] as const;
    }),
  );
  return Object.fromEntries(entries) as Record<ReportStatus, number>;
}

async function loadProfiles(ids: string[]) {
  const map = new Map<string, ProfileLite>();
  if (ids.length === 0) return map;
  const admin = createAdminClient();
  const { data } = await admin
    .from("profiles")
    .select("id, display_name, email")
    .in("id", ids);
  for (const row of (data ?? []) as ProfileLite[]) map.set(row.id, row);
  return map;
}

export async function listModerationReports(filters: ModerationFilters) {
  const admin = createAdminClient();
  const from = (filters.page - 1) * MODERATION_PAGE_SIZE;

  let query = admin
    .from("creator_content_reports")
    .select("*", { count: "exact" })
    .eq("status", filters.status)
    .order("created_at", { ascending: false })
    .range(from, from + MODERATION_PAGE_SIZE - 1);
  if (filters.targetType) query = query.eq("target_type", filters.targetType);
  if (filters.reason) query = query.eq("reason", filters.reason);

  const { data, count, error } = await query;
  if (error) throw new Error(error.message);
  const reports = (data ?? []) as ModerationReportRow[];

  const idsByType = (type: ReportTargetType) =>
    uniq(reports.filter((report) => report.target_type === type).map((report) => report.target_id));

  const [postsRes, commentsRes, storiesRes, shopTargetsRes, openRes] = await Promise.all([
    idsByType("post").length
      ? admin
          .from("shop_posts")
          .select("id, caption, media_urls, removed_at, removed_reason")
          .in("id", idsByType("post"))
      : Promise.resolve({ data: [] }),
    idsByType("comment").length
      ? admin
          .from("shop_post_comments")
          .select("id, body, author_name")
          .in("id", idsByType("comment"))
      : Promise.resolve({ data: [] }),
    idsByType("story").length
      ? admin
          .from("shop_stories")
          .select("id, caption, expires_at")
          .in("id", idsByType("story"))
      : Promise.resolve({ data: [] }),
    admin
      .from("shops")
      .select("id, name, is_active")
      .in("id", uniq([...idsByType("shop"), ...reports.map((report) => report.target_shop_id)])),
    reports.length
      ? admin
          .from("creator_content_reports")
          .select("target_type, target_id, reason, reporter_id")
          .eq("status", "open")
          .in("target_id", uniq(reports.map((report) => report.target_id)))
      : Promise.resolve({ data: [] }),
  ]);

  type PostRow = {
    id: string;
    caption: string | null;
    media_urls: unknown;
    removed_at: string | null;
    removed_reason: string | null;
  };
  type CommentRow = { id: string; body: string; author_name: string | null };
  type StoryRow = { id: string; caption: string | null; expires_at: string };
  type ShopRow = { id: string; name: string; is_active: boolean };

  const posts = new Map(((postsRes.data ?? []) as PostRow[]).map((row) => [row.id, row]));
  const comments = new Map(((commentsRes.data ?? []) as CommentRow[]).map((row) => [row.id, row]));
  const stories = new Map(((storiesRes.data ?? []) as StoryRow[]).map((row) => [row.id, row]));
  const shops = new Map(((shopTargetsRes.data ?? []) as ShopRow[]).map((row) => [row.id, row]));
  const groups = groupReportsByTarget(
    (openRes.data ?? []) as Array<{
      target_type: string;
      target_id: string;
      reason: string;
      reporter_id: string;
    }>,
  );

  const profiles = await loadProfiles(
    uniq([
      ...reports.map((report) => report.reporter_id),
      ...reports.map((report) => report.target_owner_id),
      ...reports.map((report) => report.reviewed_by),
    ]),
  );

  const banned = new Map<string, boolean>();
  await Promise.all(
    uniq(reports.map((report) => report.target_owner_id)).map(async (ownerId) => {
      try {
        const { data: userData } = await admin.auth.admin.getUserById(ownerId);
        banned.set(
          ownerId,
          isBannedUntil(
            (userData?.user as { banned_until?: string | null } | undefined)?.banned_until,
          ),
        );
      } catch {
        banned.set(ownerId, false);
      }
    }),
  );

  const now = Date.now();
  const views: ModerationReportView[] = reports.map((report) => {
    let target: ModerationTargetState;
    if (report.target_type === "post") {
      const post = posts.get(report.target_id);
      target = post
        ? {
            type: "post",
            exists: true,
            caption: post.caption ?? "",
            imageUrl: firstImageUrl(post.media_urls),
            hasMedia: Array.isArray(post.media_urls) && post.media_urls.length > 0,
            removedAt: post.removed_at,
            removedReason: post.removed_reason,
          }
        : { type: "post", exists: false };
    } else if (report.target_type === "comment") {
      const comment = comments.get(report.target_id);
      target = comment
        ? { type: "comment", exists: true, body: comment.body, authorName: comment.author_name }
        : { type: "comment", exists: false };
    } else if (report.target_type === "story") {
      const story = stories.get(report.target_id);
      target = story
        ? {
            type: "story",
            exists: true,
            caption: story.caption ?? "",
            expiresAt: story.expires_at,
            expired: new Date(story.expires_at).getTime() <= now,
          }
        : { type: "story", exists: false };
    } else {
      const shop = shops.get(report.target_id);
      target = shop
        ? { type: "shop", exists: true, name: shop.name, isActive: shop.is_active }
        : { type: "shop", exists: false };
    }

    const shopId = report.target_shop_id;
    const shop = shopId ? shops.get(shopId) : undefined;
    const reporter = profiles.get(report.reporter_id);
    const owner = report.target_owner_id ? profiles.get(report.target_owner_id) : undefined;
    const reviewer = report.reviewed_by ? profiles.get(report.reviewed_by) : undefined;

    return {
      ...report,
      reporter: reporter ? { name: reporter.display_name, email: reporter.email } : null,
      owner: owner ? { name: owner.display_name, email: owner.email } : null,
      ownerSuspended: report.target_owner_id ? (banned.get(report.target_owner_id) ?? false) : false,
      shop: shop && shopId ? { id: shopId, name: shop.name, isActive: shop.is_active } : null,
      target,
      group: groups.get(reportTargetKey(report)) ?? null,
      reviewer: reviewer?.display_name ?? reviewer?.email ?? null,
    };
  });

  return {
    reports: views,
    total: count ?? 0,
    pageSize: MODERATION_PAGE_SIZE,
  };
}

export type ModerationLogEntry = {
  id: number;
  action: string;
  target_type: string;
  target_id: string;
  report_id: string | null;
  note: string;
  created_at: string;
  adminName: string | null;
};

export async function listModerationLog(page: number) {
  const admin = createAdminClient();
  const from = (page - 1) * MODERATION_LOG_PAGE_SIZE;
  const { data, count, error } = await admin
    .from("moderation_actions")
    .select("id, admin_id, action, target_type, target_id, report_id, note, created_at", {
      count: "exact",
    })
    .order("created_at", { ascending: false })
    .order("id", { ascending: false })
    .range(from, from + MODERATION_LOG_PAGE_SIZE - 1);
  if (error) throw new Error(error.message);

  const rows = (data ?? []) as Array<Omit<ModerationLogEntry, "adminName"> & { admin_id: string | null }>;
  const profiles = await loadProfiles(uniq(rows.map((row) => row.admin_id)));
  const entries: ModerationLogEntry[] = rows.map(({ admin_id, ...row }) => {
    const profile = admin_id ? profiles.get(admin_id) : undefined;
    return { ...row, adminName: profile?.display_name ?? profile?.email ?? null };
  });
  return { entries, total: count ?? 0, pageSize: MODERATION_LOG_PAGE_SIZE };
}
