import Link from "next/link";

import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { ModerationActionForm } from "@/components/admin/moderation-action-form";
import {
  REPORT_REASONS,
  REPORT_TARGET_TYPES,
  formatReasonLabel,
  parseReasonFilter,
  parseReportStatus,
  parseTargetTypeFilter,
} from "@/lib/admin-moderation";
import {
  type ModerationReportView,
  getModerationTabCounts,
  listModerationLog,
  listModerationReports,
} from "@/lib/admin-moderation-data";
import { cn } from "@/lib/utils";

export const dynamic = "force-dynamic";

type SearchParams = { [key: string]: string | string[] | undefined };

function readParam(value: string | string[] | undefined) {
  return typeof value === "string" ? value : "";
}

function readPage(value: string | string[] | undefined) {
  const page = Number(readParam(value) || "1");
  return Number.isInteger(page) && page > 0 ? page : 1;
}

type Query = {
  view: "reports" | "log";
  status: string;
  type: string;
  reason: string;
  page: number;
};

function buildHref(query: Query, overrides: Partial<Query> = {}) {
  const next = { ...query, ...overrides };
  const params = new URLSearchParams();
  if (next.view === "log") params.set("view", "log");
  if (next.view === "reports" && next.status !== "open") params.set("status", next.status);
  if (next.view === "reports" && next.type) params.set("type", next.type);
  if (next.view === "reports" && next.reason) params.set("reason", next.reason);
  if (next.page > 1) params.set("page", String(next.page));
  const qs = params.toString();
  return qs ? `/admin/moderation?${qs}` : "/admin/moderation";
}

const pillBase =
  "inline-flex min-h-11 items-center justify-center rounded-full px-4 text-sm font-medium transition";

function formatWhen(value: string) {
  return new Date(value).toLocaleString();
}

function personLabel(person: { name: string | null; email: string | null } | null) {
  if (!person) return "Unknown";
  return [person.name, person.email].filter(Boolean).join(" · ") || "Unknown";
}

function TargetState({ report }: { report: ModerationReportView }) {
  const target = report.target;
  if (!target.exists) {
    return (
      <p className="text-sm text-muted-foreground">
        This {report.target_type} no longer exists (deleted or expired).
      </p>
    );
  }
  if (target.type === "post") {
    return (
      <div className="flex gap-3">
        {target.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={target.imageUrl}
            alt="Post preview"
            className="size-20 shrink-0 rounded-2xl border border-artisan-clay object-cover"
          />
        ) : target.hasMedia ? (
          <div className="grid size-20 shrink-0 place-items-center rounded-2xl border border-artisan-clay bg-artisan-bone text-xs text-muted-foreground">
            Video
          </div>
        ) : null}
        <div className="min-w-0 space-y-1">
          <p className="whitespace-pre-wrap break-words text-sm">
            {target.caption || <span className="text-muted-foreground">No caption</span>}
          </p>
          {target.removedAt ? (
            <p className="text-xs text-red-700">
              Removed {formatWhen(target.removedAt)}
              {target.removedReason ? `: ${target.removedReason}` : ""}
            </p>
          ) : (
            <p className="text-xs text-green-700">Currently visible</p>
          )}
        </div>
      </div>
    );
  }
  if (target.type === "comment") {
    return (
      <p className="whitespace-pre-wrap break-words text-sm">
        {target.authorName ? (
          <span className="font-medium text-artisan-sienna">{target.authorName}: </span>
        ) : null}
        {target.body}
      </p>
    );
  }
  if (target.type === "story") {
    return (
      <div className="space-y-1 text-sm">
        <p className="whitespace-pre-wrap break-words">
          {target.caption || <span className="text-muted-foreground">No caption</span>}
        </p>
        <p className={cn("text-xs", target.expired ? "text-red-700" : "text-green-700")}>
          {target.expired ? "Expired / removed" : `Live until ${formatWhen(target.expiresAt)}`}
        </p>
      </div>
    );
  }
  return (
    <p className="text-sm">
      <span className="font-medium text-artisan-sienna">{target.name}</span>{" "}
      <StatusBadge value={target.isActive ? "active" : "suspended"} />
    </p>
  );
}

function ReportActions({ report }: { report: ModerationReportView }) {
  const isOpen = report.status === "open";
  const reportId = isOpen ? report.id : null;
  const target = report.target;
  const buttons: React.ReactNode[] = [];

  if (report.target_type === "post" && target.exists && target.type === "post") {
    buttons.push(
      target.removedAt ? (
        <ModerationActionForm
          key="post"
          kind="restore_post"
          targetId={report.target_id}
          label="Restore post"
          title="Restore this post?"
          description="The post becomes visible to everyone again."
          noteRequired={false}
        />
      ) : (
        <ModerationActionForm
          key="post"
          kind="remove_post"
          targetId={report.target_id}
          reportId={reportId}
          label="Remove post"
          title="Remove this post?"
          description="The post is hidden from everyone except the maker, who sees your reason. Open reports on it are resolved."
          noteRequired
          tone="danger"
        />
      ),
    );
  }
  if (report.target_type === "comment" && target.exists) {
    buttons.push(
      <ModerationActionForm
        key="comment"
        kind="delete_comment"
        targetId={report.target_id}
        reportId={reportId}
        label="Delete comment"
        title="Permanently delete this comment?"
        description="The comment is deleted and cannot be restored. The report snapshot is kept. Open reports on it are resolved."
        noteRequired
        tone="danger"
      />,
    );
  }
  if (report.target_type === "story" && target.exists && target.type === "story" && !target.expired) {
    buttons.push(
      <ModerationActionForm
        key="story"
        kind="remove_story"
        targetId={report.target_id}
        reportId={reportId}
        label="Remove story"
        title="Remove this story now?"
        description="The story expires immediately. Open reports on it are resolved."
        noteRequired
        tone="danger"
      />,
    );
  }
  if (report.shop) {
    buttons.push(
      report.shop.isActive ? (
        <ModerationActionForm
          key="shop"
          kind="suspend_shop"
          targetId={report.shop.id}
          reportId={reportId}
          label="Suspend shop"
          title={`Suspend ${report.shop.name}?`}
          description="The shop is deactivated and hidden from buyers. Open reports on the same item are resolved."
          noteRequired
          tone="danger"
        />
      ) : (
        <ModerationActionForm
          key="shop"
          kind="restore_shop"
          targetId={report.shop.id}
          label="Restore shop"
          title={`Restore ${report.shop.name}?`}
          description="The shop becomes active again."
          noteRequired={false}
        />
      ),
    );
  }
  if (report.target_owner_id) {
    buttons.push(
      report.ownerSuspended ? (
        <ModerationActionForm
          key="user"
          kind="restore_user"
          targetId={report.target_owner_id}
          label="Restore account"
          title="Restore this account?"
          description="The maker can sign in again. Their shops stay as they are and can be restored separately."
          noteRequired={false}
        />
      ) : (
        <ModerationActionForm
          key="user"
          kind="suspend_user"
          targetId={report.target_owner_id}
          reportId={reportId}
          label="Suspend account"
          title="Suspend this maker's account?"
          description="The account is banned from signing in and all of their shops are suspended."
          noteRequired
          tone="danger"
        />
      ),
    );
  }
  if (isOpen) {
    buttons.push(
      <ModerationActionForm
        key="resolve"
        kind="resolve_report"
        targetId={report.id}
        reportId={report.id}
        label="Resolve"
        title="Resolve this report?"
        description="Marks the report resolved. If the content is already taken down, other open reports on it are resolved too."
        noteRequired={false}
        tone="primary"
      />,
      <ModerationActionForm
        key="dismiss"
        kind="dismiss_report"
        targetId={report.id}
        reportId={report.id}
        label="Dismiss"
        title="Dismiss this report?"
        description="No action is taken on the content. Only this report is closed."
        noteRequired={false}
      />,
    );
  }

  return <div className="flex flex-wrap items-start gap-2">{buttons}</div>;
}

function ReportCard({ report }: { report: ModerationReportView }) {
  const duplicates = report.group && report.status === "open" ? report.group.count : 0;

  return (
    <div className="rounded-3xl border border-artisan-clay bg-white p-4 sm:p-5">
      <div className="flex flex-wrap items-center gap-2">
        <span className="rounded-full border border-artisan-clay bg-artisan-bone px-3 py-1 text-xs font-medium capitalize text-artisan-sienna">
          {report.target_type}
        </span>
        <span className="rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-medium text-amber-700">
          {formatReasonLabel(report.reason)}
        </span>
        <StatusBadge value={report.status} />
        {duplicates > 1 ? (
          <span className="rounded-full border border-red-200 bg-red-50 px-3 py-1 text-xs font-medium text-red-700">
            {duplicates} open reports on this item
          </span>
        ) : null}
        <span className="ml-auto text-xs text-muted-foreground">{formatWhen(report.created_at)}</span>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <div className="space-y-2 text-sm">
          <p>
            <span className="font-medium text-artisan-sienna">Reporter:</span>{" "}
            {personLabel(report.reporter)}
          </p>
          <p>
            <span className="font-medium text-artisan-sienna">Maker:</span>{" "}
            {personLabel(report.owner)}{" "}
            {report.ownerSuspended ? <StatusBadge value="suspended" /> : null}
          </p>
          {report.shop ? (
            <p>
              <span className="font-medium text-artisan-sienna">Shop:</span>{" "}
              <Link
                href={`/admin/shops/${report.shop.id}`}
                className="inline-flex min-h-11 items-center font-medium text-artisan-terracotta underline underline-offset-2"
              >
                {report.shop.name}
              </Link>{" "}
              <StatusBadge value={report.shop.isActive ? "active" : "suspended"} />
            </p>
          ) : null}
          <p className="whitespace-pre-wrap break-words">
            <span className="font-medium text-artisan-sienna">Details:</span>{" "}
            {report.details || <span className="text-muted-foreground">None provided</span>}
          </p>
          {duplicates > 1 && report.group ? (
            <p className="text-xs text-muted-foreground">
              Reasons on this item:{" "}
              {Object.entries(report.group.reasonCounts)
                .map(([reason, count]) => `${formatReasonLabel(reason)} (${count})`)
                .join(", ")}
            </p>
          ) : null}
        </div>

        <div className="space-y-3">
          <div className="rounded-2xl border border-artisan-clay bg-artisan-bone/30 p-3">
            <p className="mb-1 text-xs font-medium uppercase tracking-wide text-artisan-terracotta">
              Snapshot when reported
            </p>
            <p className="whitespace-pre-wrap break-words text-sm">
              {report.target_text_snapshot || (
                <span className="text-muted-foreground">No text captured</span>
              )}
            </p>
          </div>
          <div className="rounded-2xl border border-artisan-clay bg-white p-3">
            <p className="mb-2 text-xs font-medium uppercase tracking-wide text-artisan-terracotta">
              Current state
            </p>
            <TargetState report={report} />
          </div>
        </div>
      </div>

      {report.status !== "open" ? (
        <p className="mt-4 text-sm text-muted-foreground">
          <span className="font-medium text-artisan-sienna">Resolution notes:</span>{" "}
          {report.resolution_notes || "None"}
          {report.reviewed_at ? ` (${formatWhen(report.reviewed_at)})` : ""}
        </p>
      ) : null}

      <div className="mt-4">
        <ReportActions report={report} />
      </div>
    </div>
  );
}

function Pagination({
  query,
  total,
  pageSize,
}: {
  query: Query;
  total: number;
  pageSize: number;
}) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  if (totalPages <= 1) return null;
  const prev = Math.max(1, query.page - 1);
  const next = Math.min(totalPages, query.page + 1);
  return (
    <div className="mt-6 flex items-center justify-between gap-3">
      <Link
        href={buildHref(query, { page: prev })}
        aria-disabled={query.page <= 1}
        className={cn(pillBase, "border border-artisan-clay bg-white text-artisan-sienna", query.page <= 1 && "pointer-events-none opacity-50")}
      >
        Previous
      </Link>
      <span className="text-sm text-muted-foreground">
        Page {query.page} of {totalPages} ({total} total)
      </span>
      <Link
        href={buildHref(query, { page: next })}
        aria-disabled={query.page >= totalPages}
        className={cn(pillBase, "border border-artisan-clay bg-white text-artisan-sienna", query.page >= totalPages && "pointer-events-none opacity-50")}
      >
        Next
      </Link>
    </div>
  );
}

export default async function AdminModerationPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const params = await searchParams;
  const view = readParam(params.view) === "log" ? "log" : "reports";
  const status = parseReportStatus(readParam(params.status));
  const type = parseTargetTypeFilter(readParam(params.type));
  const reason = parseReasonFilter(readParam(params.reason));
  const page = readPage(params.page);
  const query: Query = { view, status, type, reason, page };

  return (
    <>
      <AdminPageHeader
        eyebrow="Moderation"
        title="Content Reports"
        description="Review reports on creator posts, comments, stories and shops. Every action is recorded in the moderation log."
      />

      <div className="mb-4 flex flex-wrap gap-2">
        <Link
          href={buildHref(query, { view: "reports", page: 1 })}
          className={cn(pillBase, view === "reports" ? "bg-artisan-terracotta text-white" : "bg-artisan-bone text-artisan-sienna")}
        >
          Reports
        </Link>
        <Link
          href={buildHref(query, { view: "log", page: 1 })}
          className={cn(pillBase, view === "log" ? "bg-artisan-terracotta text-white" : "bg-artisan-bone text-artisan-sienna")}
        >
          Moderation log
        </Link>
      </div>

      {view === "log" ? <LogView query={query} /> : <ReportsView query={query} />}
    </>
  );
}

async function LogView({ query }: { query: Query }) {
  const { entries, total, pageSize } = await listModerationLog(query.page);
  return (
    <PanelCard title="Moderation Log" description="Most recent admin actions first.">
      {entries.length === 0 ? (
        <p className="text-sm text-muted-foreground">No moderation actions recorded yet.</p>
      ) : (
        <div className="space-y-3">
          {entries.map((entry) => (
            <div key={entry.id} className="rounded-2xl border border-artisan-clay bg-white p-4 text-sm">
              <div className="flex flex-wrap items-center gap-2">
                <span className="rounded-full border border-artisan-clay bg-artisan-bone px-3 py-1 text-xs font-medium text-artisan-sienna">
                  {formatReasonLabel(entry.action)}
                </span>
                <span className="text-xs capitalize text-muted-foreground">
                  {entry.target_type} · {entry.target_id.slice(0, 8)}
                </span>
                <span className="ml-auto text-xs text-muted-foreground">
                  {formatWhen(entry.created_at)}
                </span>
              </div>
              <p className="mt-2">
                <span className="font-medium text-artisan-sienna">Admin:</span>{" "}
                {entry.adminName ?? "Unknown"}
              </p>
              {entry.note ? (
                <p className="mt-1 whitespace-pre-wrap break-words">
                  <span className="font-medium text-artisan-sienna">Note:</span> {entry.note}
                </p>
              ) : null}
            </div>
          ))}
        </div>
      )}
      <Pagination query={query} total={total} pageSize={pageSize} />
    </PanelCard>
  );
}

async function ReportsView({ query }: { query: Query }) {
  const status = parseReportStatus(query.status);
  const targetType = parseTargetTypeFilter(query.type);
  const reason = parseReasonFilter(query.reason);
  const [counts, list] = await Promise.all([
    getModerationTabCounts({ targetType, reason }),
    listModerationReports({ status, targetType, reason, page: query.page }),
  ]);

  return (
    <>
      <div className="mb-4 flex flex-wrap gap-2">
        {(["open", "resolved", "dismissed"] as const).map((tab) => (
          <Link
            key={tab}
            href={buildHref(query, { status: tab, page: 1 })}
            className={cn(pillBase, "capitalize", status === tab ? "bg-artisan-sienna text-white" : "bg-white text-artisan-sienna border border-artisan-clay")}
          >
            {tab} ({counts[tab]})
          </Link>
        ))}
      </div>

      <form
        method="get"
        action="/admin/moderation"
        className="mb-4 grid gap-3 rounded-3xl border border-artisan-clay/70 bg-white/85 p-4 sm:grid-cols-2 lg:grid-cols-[1fr_1fr_auto_auto]"
      >
        {status !== "open" ? <input type="hidden" name="status" value={status} /> : null}
        <select
          name="type"
          defaultValue={targetType}
          aria-label="Filter by target type"
          className="min-h-11 rounded-2xl border border-artisan-clay bg-white px-3 text-sm"
        >
          <option value="">All target types</option>
          {REPORT_TARGET_TYPES.map((value) => (
            <option key={value} value={value}>
              {formatReasonLabel(value)}
            </option>
          ))}
        </select>
        <select
          name="reason"
          defaultValue={reason}
          aria-label="Filter by reason"
          className="min-h-11 rounded-2xl border border-artisan-clay bg-white px-3 text-sm"
        >
          <option value="">All reasons</option>
          {REPORT_REASONS.map((value) => (
            <option key={value} value={value}>
              {formatReasonLabel(value)}
            </option>
          ))}
        </select>
        <button
          type="submit"
          className="min-h-11 rounded-2xl bg-artisan-terracotta px-5 text-sm font-medium text-white hover:bg-artisan-terracotta-dark"
        >
          Apply filters
        </button>
        <Link
          href={buildHref({ ...query, type: "", reason: "" }, { page: 1 })}
          className="inline-flex min-h-11 items-center justify-center rounded-2xl border border-artisan-clay bg-white px-5 text-sm font-medium text-artisan-sienna"
        >
          Clear
        </Link>
      </form>

      <PanelCard title={`${formatReasonLabel(status)} Reports`} description="Newest first.">
        {list.reports.length === 0 ? (
          <p className="text-sm text-muted-foreground">No {status} reports match these filters.</p>
        ) : (
          <div className="space-y-4">
            {list.reports.map((report) => (
              <ReportCard key={report.id} report={report} />
            ))}
          </div>
        )}
        <Pagination query={query} total={list.total} pageSize={list.pageSize} />
      </PanelCard>
    </>
  );
}
