"use server";

import { revalidatePath } from "next/cache";

import type { AdminActionState } from "@/lib/admin-action-state";
import { requireAdminSession } from "@/lib/admin-auth";
import {
  type ModerationActionKind,
  type ModerationLogTargetType,
  chatThreadPreview,
  isModerationAction,
  isTakedownAction,
  planModerationAction,
  validateModerationNote,
} from "@/lib/admin-moderation";
import { createAdminClient } from "@/lib/supabase/admin";

type AdminClient = ReturnType<typeof createAdminClient>;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function successState(message: string): AdminActionState {
  return { status: "success", message, savedAt: new Date().toISOString() };
}

function errorState(error: unknown, fallback: string): AdminActionState {
  return {
    status: "error",
    message: error instanceof Error ? error.message : fallback,
    savedAt: null,
  };
}

async function logModerationAction(
  admin: AdminClient,
  entry: {
    adminId: string;
    action: ModerationActionKind;
    targetType: ModerationLogTargetType;
    targetId: string;
    reportId?: string | null;
    note: string;
  },
) {
  const { error } = await admin.from("moderation_actions").insert({
    admin_id: entry.adminId,
    action: entry.action,
    target_type: entry.targetType,
    target_id: entry.targetId,
    report_id: entry.reportId ?? null,
    note: entry.note,
  });
  if (error) throw new Error(`Action applied but logging failed: ${error.message}`);
}

type ReportTarget = { id: string; target_type: string; target_id: string };

/** Keeps a conversation's inbox preview from showing a deleted message. */
async function refreshChatThreadPreview(admin: AdminClient, threadId: string) {
  const { data: latest, error } = await admin
    .from("chat_messages")
    .select("body, attachment_name, message_type, sender_id, created_at")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(`Message deleted but the inbox preview was not updated: ${error.message}`);
  const row = latest as {
    body: string | null;
    attachment_name: string | null;
    message_type: string;
    sender_id: string;
    created_at: string;
  } | null;
  const { error: updateError } = await admin
    .from("chat_threads")
    .update(
      row
        ? {
            last_message_preview: chatThreadPreview(row),
            last_message_type: row.message_type,
            last_message_sender_id: row.sender_id,
            last_message_at: row.created_at,
          }
        : {
            last_message_preview: null,
            last_message_sender_id: null,
            last_message_at: null,
          },
    )
    .eq("id", threadId);
  if (updateError) {
    throw new Error(`Message deleted but the inbox preview was not updated: ${updateError.message}`);
  }
}

/** Closes a report and every other open report on the same item, logging each one. */
async function closeReports(
  admin: AdminClient,
  adminId: string,
  primary: ReportTarget,
  action: "resolve_report" | "dismiss_report",
  note: string,
  includeDuplicates: boolean,
) {
  const plan = planModerationAction(action, note);
  if (plan.change.kind !== "report_status") return 0;

  let query = admin
    .from("creator_content_reports")
    // The server records which admin reviewed it (the database keeps it).
    .update({ ...plan.change.values, reviewed_by: adminId })
    .eq("status", "open");
  query = includeDuplicates
    ? query.eq("target_type", primary.target_type).eq("target_id", primary.target_id)
    : query.eq("id", primary.id);
  const { data, error } = await query.select("id");
  if (error) throw new Error(error.message);

  const closed = (data ?? []) as Array<{ id: string }>;
  for (const row of closed) {
    await logModerationAction(admin, {
      adminId,
      action,
      targetType: "report",
      targetId: row.id,
      reportId: row.id,
      note,
    });
  }
  return closed.length;
}

async function isReportedTargetTakenDown(admin: AdminClient, report: ReportTarget) {
  switch (report.target_type) {
    case "post": {
      const { data } = await admin
        .from("shop_posts")
        .select("removed_at")
        .eq("id", report.target_id)
        .maybeSingle();
      return !data || data.removed_at !== null;
    }
    case "comment": {
      const { data } = await admin
        .from("shop_post_comments")
        .select("id")
        .eq("id", report.target_id)
        .maybeSingle();
      return !data;
    }
    case "story": {
      const { data } = await admin
        .from("shop_stories")
        .select("expires_at")
        .eq("id", report.target_id)
        .maybeSingle();
      return !data || new Date(data.expires_at).getTime() <= Date.now();
    }
    case "shop": {
      const { data } = await admin
        .from("shops")
        .select("is_active")
        .eq("id", report.target_id)
        .maybeSingle();
      return !data || data.is_active === false;
    }
    case "product_review":
    case "shop_review":
    case "message": {
      const table =
        report.target_type === "product_review"
          ? "product_reviews"
          : report.target_type === "shop_review"
            ? "shop_reviews"
            : "chat_messages";
      const { data } = await admin.from(table).select("id").eq("id", report.target_id).maybeSingle();
      return !data;
    }
    default:
      return false;
  }
}

export async function runModerationAction(
  _previousState: AdminActionState,
  formData: FormData,
): Promise<AdminActionState> {
  try {
    const session = await requireAdminSession();
    const adminId = session.profile.id;

    const kindValue = formData.get("kind");
    if (!isModerationAction(kindValue)) throw new Error("Unknown moderation action.");
    const kind = kindValue;

    const targetId = String(formData.get("targetId") ?? "");
    if (!UUID_PATTERN.test(targetId)) throw new Error("Invalid target.");
    const reportIdRaw = String(formData.get("reportId") ?? "");
    const reportId = reportIdRaw ? reportIdRaw : null;
    if (reportId && !UUID_PATTERN.test(reportId)) throw new Error("Invalid report.");

    const validation = validateModerationNote(kind, formData.get("note"));
    if (!validation.ok) throw new Error(validation.error);
    const note = validation.note;

    const admin = createAdminClient();
    const plan = planModerationAction(kind, note);
    let message = "Done.";

    // Reports are addressed by report id for resolve/dismiss; everything else by target id.
    if (plan.change.kind === "report_status") {
      const closeId = reportId ?? targetId;
      const { data: report, error } = await admin
        .from("creator_content_reports")
        .select("id, target_type, target_id, status")
        .eq("id", closeId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!report) throw new Error("Report not found.");
      if (report.status !== "open") throw new Error("This report has already been reviewed.");

      const sweep = kind === "resolve_report" && (await isReportedTargetTakenDown(admin, report));
      const closed = await closeReports(
        admin,
        adminId,
        report,
        kind === "resolve_report" ? "resolve_report" : "dismiss_report",
        note,
        sweep,
      );
      message =
        kind === "dismiss_report"
          ? "Report dismissed."
          : closed > 1
            ? `Report resolved along with ${closed - 1} duplicate report(s).`
            : "Report resolved.";
    } else if (plan.change.kind === "auth_ban") {
      if (targetId === adminId) throw new Error("You cannot suspend your own account.");
      const { data: profile } = await admin
        .from("profiles")
        .select("id, role")
        .eq("id", targetId)
        .maybeSingle();
      if (!profile) throw new Error("User not found.");
      if (profile.role === "admin") throw new Error("Admin accounts cannot be suspended here.");

      const { error } = await admin.auth.admin.updateUserById(targetId, {
        ban_duration: plan.change.banDuration,
      });
      if (error) throw new Error(`Unable to update the account: ${error.message}`);
      await logModerationAction(admin, {
        adminId,
        action: kind,
        targetType: "user",
        targetId,
        reportId: isTakedownAction(kind) ? reportId : null,
        note,
      });

      if (kind === "suspend_user") {
        const shopPlan = planModerationAction("suspend_shop", note);
        if (shopPlan.change.kind === "update") {
          const { data: shops, error: shopError } = await admin
            .from("shops")
            .update(shopPlan.change.values)
            .eq("vendor_id", targetId)
            .eq("is_active", true)
            .select("id");
          if (shopError) throw new Error(shopError.message);
          for (const shop of (shops ?? []) as Array<{ id: string }>) {
            await logModerationAction(admin, {
              adminId,
              action: "suspend_shop",
              targetType: "shop",
              targetId: shop.id,
              reportId,
              note,
            });
          }
        }
      }
      message = kind === "suspend_user" ? "Account and shop suspended." : "Account restored.";
    } else {
      const change = plan.change;
      const table = change.table;
      let messageThreadId: string | null = null;
      if (kind === "delete_message") {
        const { data: messageRow } = await admin
          .from("chat_messages")
          .select("thread_id")
          .eq("id", targetId)
          .maybeSingle();
        messageThreadId = (messageRow as { thread_id: string } | null)?.thread_id ?? null;
      }
      const result =
        change.kind === "delete"
          ? await admin.from(table).delete().eq("id", targetId).select("id")
          : await admin.from(table).update(change.values).eq("id", targetId).select("id");
      if (result.error) throw new Error(result.error.message);
      if (!result.data || result.data.length === 0) {
        throw new Error("That content no longer exists.");
      }
      if (messageThreadId) await refreshChatThreadPreview(admin, messageThreadId);
      await logModerationAction(admin, {
        adminId,
        action: kind,
        targetType: plan.logTargetType,
        targetId,
        reportId: isTakedownAction(kind) ? reportId : null,
        note,
      });
      message =
        {
          remove_post: "Post removed.",
          restore_post: "Post restored.",
          delete_comment: "Comment deleted.",
          remove_story: "Story removed.",
          suspend_shop: "Shop suspended.",
          restore_shop: "Shop restored.",
          delete_product_review: "Review deleted.",
          delete_shop_review: "Review deleted.",
          delete_message: "Message deleted.",
        }[kind as string] ?? "Done.";
    }

    // A takedown made from a report closes that report and its duplicates.
    if (isTakedownAction(kind) && reportId) {
      const { data: report } = await admin
        .from("creator_content_reports")
        .select("id, target_type, target_id, status")
        .eq("id", reportId)
        .maybeSingle();
      if (report && report.status === "open") {
        const closed = await closeReports(admin, adminId, report, "resolve_report", note, true);
        if (closed > 0) message = `${message} ${closed} report(s) resolved.`;
      }
    }

    revalidatePath("/admin");
    revalidatePath("/admin/moderation");
    revalidatePath("/admin/shops");
    if (kind === "suspend_shop" || kind === "restore_shop") {
      revalidatePath(`/admin/shops/${targetId}`);
    }

    return successState(message);
  } catch (error) {
    return errorState(error, "Unable to complete the moderation action.");
  }
}
