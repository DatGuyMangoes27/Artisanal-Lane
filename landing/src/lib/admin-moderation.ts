// Pure moderation helpers (no I/O) so they can be unit tested without the database.

export const REPORT_TARGET_TYPES = [
  "post",
  "comment",
  "story",
  "shop",
  "product_review",
  "shop_review",
  "message",
] as const;
export type ReportTargetType = (typeof REPORT_TARGET_TYPES)[number];

export const REPORT_REASONS = [
  "spam",
  "harassment",
  "hate_or_abuse",
  "sexual_content",
  "intellectual_property",
  "other",
] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

export const REPORT_STATUSES = ["open", "resolved", "dismissed"] as const;
export type ReportStatus = (typeof REPORT_STATUSES)[number];

export const MODERATION_ACTIONS = [
  "remove_post",
  "restore_post",
  "delete_comment",
  "remove_story",
  "suspend_shop",
  "restore_shop",
  "suspend_user",
  "restore_user",
  "resolve_report",
  "dismiss_report",
  "delete_product_review",
  "delete_shop_review",
  "delete_message",
] as const;
export type ModerationActionKind = (typeof MODERATION_ACTIONS)[number];

export type ModerationLogTargetType =
  | "post"
  | "comment"
  | "story"
  | "shop"
  | "user"
  | "report"
  | "product_review"
  | "shop_review"
  | "message";

const TARGET_TYPE_LABELS: Record<ReportTargetType, string> = {
  post: "Post",
  comment: "Comment",
  story: "Story",
  shop: "Shop",
  product_review: "Product review",
  shop_review: "Shop review",
  message: "Chat message",
};

export function formatTargetTypeLabel(type: string) {
  return TARGET_TYPE_LABELS[type as ReportTargetType] ?? formatReasonLabel(type);
}

/** Who `target_owner_id` is for a report type: the maker, or the review/message author. */
export function ownerRoleLabel(type: string) {
  if (type === "product_review" || type === "shop_review") return "Reviewer";
  if (type === "message") return "Sender";
  return "Maker";
}

/**
 * Shop suspension is offered only when the reported item is the shop's own
 * content. A review's shop is the shop being reviewed and a message's shop is
 * the conversation's shop, so those reports act on the author's account instead.
 */
export function canSuspendShopForTarget(type: string) {
  return type === "post" || type === "comment" || type === "story" || type === "shop";
}

/** The takedown that deletes a reported review or message, if any. */
export function deleteActionForTarget(type: string): ModerationActionKind | null {
  if (type === "product_review") return "delete_product_review";
  if (type === "shop_review") return "delete_shop_review";
  if (type === "message") return "delete_message";
  return null;
}

/**
 * Inbox preview for a conversation after a message is deleted, mirroring
 * public.touch_chat_thread_on_message. Null when no messages remain.
 */
export function chatThreadPreview(
  latest: { body: string | null; attachment_name: string | null } | null,
): string | null {
  if (!latest) return null;
  const body = latest.body?.trim() ?? "";
  if (body.length > 0) return body.slice(0, 120);
  return latest.attachment_name ?? "Attachment";
}

export const MODERATION_PAGE_SIZE = 10;
export const MODERATION_LOG_PAGE_SIZE = 25;
export const USER_BAN_DURATION = "876000h";

export function isModerationAction(value: unknown): value is ModerationActionKind {
  return typeof value === "string" && (MODERATION_ACTIONS as readonly string[]).includes(value);
}

export function parseReportStatus(value: string | null | undefined): ReportStatus {
  return (REPORT_STATUSES as readonly string[]).includes(value ?? "")
    ? (value as ReportStatus)
    : "open";
}

export function parseTargetTypeFilter(value: string | null | undefined): ReportTargetType | "" {
  return (REPORT_TARGET_TYPES as readonly string[]).includes(value ?? "")
    ? (value as ReportTargetType)
    : "";
}

export function parseReasonFilter(value: string | null | undefined): ReportReason | "" {
  return (REPORT_REASONS as readonly string[]).includes(value ?? "")
    ? (value as ReportReason)
    : "";
}

export function formatReasonLabel(reason: string) {
  const label = reason.replace(/_/g, " ");
  return label.charAt(0).toUpperCase() + label.slice(1);
}

/** Actions that take content or accounts down and therefore need a written reason. */
const NOTE_REQUIRED: ReadonlySet<ModerationActionKind> = new Set([
  "remove_post",
  "delete_comment",
  "remove_story",
  "suspend_shop",
  "suspend_user",
  "delete_product_review",
  "delete_shop_review",
  "delete_message",
]);

export function isNoteRequired(kind: ModerationActionKind) {
  return NOTE_REQUIRED.has(kind);
}

export function maxNoteLength(kind: ModerationActionKind) {
  // shop_posts.removed_reason is limited to 500 characters; log/report notes to 1000.
  return kind === "remove_post" ? 500 : 1000;
}

export type NoteValidation =
  | { ok: true; note: string }
  | { ok: false; error: string };

export function validateModerationNote(
  kind: ModerationActionKind,
  rawNote: unknown,
): NoteValidation {
  const note = typeof rawNote === "string" ? rawNote.trim() : "";
  if (isNoteRequired(kind) && note.length === 0) {
    return { ok: false, error: "A note explaining the reason is required for this action." };
  }
  const max = maxNoteLength(kind);
  if (note.length > max) {
    return { ok: false, error: `Note must be ${max} characters or fewer.` };
  }
  return { ok: true, note };
}

export type ModerationChange =
  | { kind: "update"; table: "shop_posts"; values: Record<string, unknown> }
  | { kind: "update"; table: "shop_stories"; values: Record<string, unknown> }
  | { kind: "update"; table: "shops"; values: Record<string, unknown> }
  | { kind: "delete"; table: "shop_post_comments" | "product_reviews" | "shop_reviews" | "chat_messages" }
  | { kind: "auth_ban"; banDuration: string }
  | { kind: "report_status"; values: Record<string, unknown> };

export type ModerationPlan = {
  action: ModerationActionKind;
  logTargetType: ModerationLogTargetType;
  change: ModerationChange;
};

/** Maps a moderation action to the log target type and the database change it performs. */
export function planModerationAction(
  kind: ModerationActionKind,
  note: string,
  now: Date = new Date(),
): ModerationPlan {
  const iso = now.toISOString();
  switch (kind) {
    case "remove_post":
      return {
        action: kind,
        logTargetType: "post",
        change: {
          kind: "update",
          table: "shop_posts",
          values: { removed_at: iso, removed_reason: note },
        },
      };
    case "restore_post":
      return {
        action: kind,
        logTargetType: "post",
        change: {
          kind: "update",
          table: "shop_posts",
          values: { removed_at: null, removed_reason: null },
        },
      };
    case "delete_comment":
      return {
        action: kind,
        logTargetType: "comment",
        change: { kind: "delete", table: "shop_post_comments" },
      };
    case "delete_product_review":
      return {
        action: kind,
        logTargetType: "product_review",
        change: { kind: "delete", table: "product_reviews" },
      };
    case "delete_shop_review":
      return {
        action: kind,
        logTargetType: "shop_review",
        change: { kind: "delete", table: "shop_reviews" },
      };
    case "delete_message":
      return {
        action: kind,
        logTargetType: "message",
        change: { kind: "delete", table: "chat_messages" },
      };
    case "remove_story":
      return {
        action: kind,
        logTargetType: "story",
        change: { kind: "update", table: "shop_stories", values: { expires_at: iso } },
      };
    case "suspend_shop":
      return {
        action: kind,
        logTargetType: "shop",
        change: { kind: "update", table: "shops", values: { is_active: false } },
      };
    case "restore_shop":
      return {
        action: kind,
        logTargetType: "shop",
        change: { kind: "update", table: "shops", values: { is_active: true } },
      };
    case "suspend_user":
      return {
        action: kind,
        logTargetType: "user",
        change: { kind: "auth_ban", banDuration: USER_BAN_DURATION },
      };
    case "restore_user":
      return {
        action: kind,
        logTargetType: "user",
        change: { kind: "auth_ban", banDuration: "none" },
      };
    case "resolve_report":
      return {
        action: kind,
        logTargetType: "report",
        change: {
          kind: "report_status",
          values: { status: "resolved", resolution_notes: note },
        },
      };
    case "dismiss_report":
      return {
        action: kind,
        logTargetType: "report",
        change: {
          kind: "report_status",
          values: { status: "dismissed", resolution_notes: note },
        },
      };
  }
}

/** Takedown actions that also close the report they were opened from (and its duplicates). */
export function isTakedownAction(kind: ModerationActionKind) {
  return (
    kind === "remove_post" ||
    kind === "delete_comment" ||
    kind === "remove_story" ||
    kind === "suspend_shop" ||
    kind === "suspend_user" ||
    kind === "delete_product_review" ||
    kind === "delete_shop_review" ||
    kind === "delete_message"
  );
}

export type ReportKeyInput = {
  target_type: string;
  target_id: string;
};

export function reportTargetKey(report: ReportKeyInput) {
  return `${report.target_type}:${report.target_id}`;
}

export type ReportGroup = {
  key: string;
  count: number;
  reasons: string[];
  reasonCounts: Record<string, number>;
  reporterIds: string[];
};

/** Groups reports by the item they target, counting reasons and distinct reporters. */
export function groupReportsByTarget(
  reports: Array<ReportKeyInput & { reason: string; reporter_id: string }>,
): Map<string, ReportGroup> {
  const groups = new Map<string, ReportGroup>();
  for (const report of reports) {
    const key = reportTargetKey(report);
    let group = groups.get(key);
    if (!group) {
      group = { key, count: 0, reasons: [], reasonCounts: {}, reporterIds: [] };
      groups.set(key, group);
    }
    group.count += 1;
    group.reasonCounts[report.reason] = (group.reasonCounts[report.reason] ?? 0) + 1;
    if (!group.reasons.includes(report.reason)) group.reasons.push(report.reason);
    if (!group.reporterIds.includes(report.reporter_id)) group.reporterIds.push(report.reporter_id);
  }
  return groups;
}

/** First http(s) image URL from a post's media_urls (videos use artisan-post:// paths). */
export function firstImageUrl(mediaUrls: unknown): string | null {
  if (!Array.isArray(mediaUrls)) return null;
  for (const item of mediaUrls) {
    if (
      typeof item === "string" &&
      /^https?:\/\//i.test(item) &&
      !/\.(mp4|mov|webm)(\?|$)/i.test(item)
    ) {
      return item;
    }
  }
  return null;
}

export function isBannedUntil(bannedUntil: string | null | undefined, now: Date = new Date()) {
  if (!bannedUntil) return false;
  const time = new Date(bannedUntil).getTime();
  return Number.isFinite(time) && time > now.getTime();
}
