import { describe, expect, it } from "vitest";

import {
  firstImageUrl,
  groupReportsByTarget,
  isBannedUntil,
  isNoteRequired,
  isTakedownAction,
  parseReasonFilter,
  parseReportStatus,
  parseTargetTypeFilter,
  planModerationAction,
  validateModerationNote,
} from "./admin-moderation";

const now = new Date("2026-09-29T10:00:00.000Z");

describe("groupReportsByTarget", () => {
  it("groups duplicate reports on the same item and counts reasons and reporters", () => {
    const groups = groupReportsByTarget([
      { target_type: "post", target_id: "p1", reason: "spam", reporter_id: "u1" },
      { target_type: "post", target_id: "p1", reason: "spam", reporter_id: "u2" },
      { target_type: "post", target_id: "p1", reason: "harassment", reporter_id: "u3" },
      { target_type: "comment", target_id: "p1", reason: "other", reporter_id: "u1" },
    ]);
    const post = groups.get("post:p1");
    expect(post?.count).toBe(3);
    expect(post?.reasons).toEqual(["spam", "harassment"]);
    expect(post?.reasonCounts).toEqual({ spam: 2, harassment: 1 });
    expect(post?.reporterIds).toEqual(["u1", "u2", "u3"]);
    // Same id under a different type is a different item.
    expect(groups.get("comment:p1")?.count).toBe(1);
    expect(groups.size).toBe(2);
  });

  it("returns an empty map for no reports", () => {
    expect(groupReportsByTarget([]).size).toBe(0);
  });
});

describe("planModerationAction", () => {
  it("removes a post with the note as the reason and restores by clearing both", () => {
    const remove = planModerationAction("remove_post", "Spam links", now);
    expect(remove.logTargetType).toBe("post");
    expect(remove.change).toEqual({
      kind: "update",
      table: "shop_posts",
      values: { removed_at: now.toISOString(), removed_reason: "Spam links" },
    });
    expect(planModerationAction("restore_post", "", now).change).toEqual({
      kind: "update",
      table: "shop_posts",
      values: { removed_at: null, removed_reason: null },
    });
  });

  it("hard deletes comments and expires stories immediately", () => {
    expect(planModerationAction("delete_comment", "x", now).change).toEqual({
      kind: "delete",
      table: "shop_post_comments",
    });
    expect(planModerationAction("remove_story", "x", now).change).toEqual({
      kind: "update",
      table: "shop_stories",
      values: { expires_at: now.toISOString() },
    });
  });

  it("toggles shops and bans or unbans users via auth", () => {
    expect(planModerationAction("suspend_shop", "x", now).change).toMatchObject({
      values: { is_active: false },
    });
    expect(planModerationAction("restore_shop", "", now).change).toMatchObject({
      values: { is_active: true },
    });
    expect(planModerationAction("suspend_user", "x", now)).toMatchObject({
      logTargetType: "user",
      change: { kind: "auth_ban", banDuration: "876000h" },
    });
    expect(planModerationAction("restore_user", "", now).change).toEqual({
      kind: "auth_ban",
      banDuration: "none",
    });
  });

  it("maps resolve and dismiss to report status updates", () => {
    expect(planModerationAction("resolve_report", "done", now)).toMatchObject({
      logTargetType: "report",
      change: { kind: "report_status", values: { status: "resolved", resolution_notes: "done" } },
    });
    expect(planModerationAction("dismiss_report", "ok", now).change).toMatchObject({
      values: { status: "dismissed", resolution_notes: "ok" },
    });
  });
});

describe("validateModerationNote", () => {
  it("requires a note for takedowns and suspensions", () => {
    for (const kind of [
      "remove_post",
      "delete_comment",
      "remove_story",
      "suspend_shop",
      "suspend_user",
    ] as const) {
      expect(isNoteRequired(kind)).toBe(true);
      expect(validateModerationNote(kind, "   ").ok).toBe(false);
      expect(isTakedownAction(kind)).toBe(true);
    }
  });

  it("allows empty notes for restores, resolve and dismiss", () => {
    for (const kind of [
      "restore_post",
      "restore_shop",
      "restore_user",
      "resolve_report",
      "dismiss_report",
    ] as const) {
      expect(validateModerationNote(kind, "")).toEqual({ ok: true, note: "" });
      expect(isTakedownAction(kind)).toBe(false);
    }
  });

  it("trims and enforces length limits (500 for post removal reason, 1000 otherwise)", () => {
    expect(validateModerationNote("suspend_shop", "  reason  ")).toEqual({ ok: true, note: "reason" });
    expect(validateModerationNote("remove_post", "a".repeat(500)).ok).toBe(true);
    expect(validateModerationNote("remove_post", "a".repeat(501)).ok).toBe(false);
    expect(validateModerationNote("suspend_shop", "a".repeat(1000)).ok).toBe(true);
    expect(validateModerationNote("suspend_shop", "a".repeat(1001)).ok).toBe(false);
    expect(validateModerationNote("resolve_report", null)).toEqual({ ok: true, note: "" });
  });
});

describe("misc helpers", () => {
  it("parses filters defensively", () => {
    expect(parseReportStatus("bogus")).toBe("open");
    expect(parseReportStatus("dismissed")).toBe("dismissed");
    expect(parseTargetTypeFilter("story")).toBe("story");
    expect(parseTargetTypeFilter("user")).toBe("");
    expect(parseReasonFilter("spam")).toBe("spam");
    expect(parseReasonFilter("x")).toBe("");
  });

  it("finds the first image url and ignores private video paths", () => {
    expect(
      firstImageUrl(["artisan-post://u/1.mp4", "https://x/y.jpg", "https://x/z.jpg"]),
    ).toBe("https://x/y.jpg");
    expect(firstImageUrl(["https://x/v.mp4"])).toBeNull();
    expect(firstImageUrl(null)).toBeNull();
  });

  it("detects active bans", () => {
    expect(isBannedUntil("2126-01-01T00:00:00Z", now)).toBe(true);
    expect(isBannedUntil("2020-01-01T00:00:00Z", now)).toBe(false);
    expect(isBannedUntil(null, now)).toBe(false);
  });
});
