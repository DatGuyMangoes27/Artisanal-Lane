"use client";

import { useState, useTransition } from "react";

import {
  applyApprovedChange,
  applyCustomChange,
  previewApprovedChange,
  previewCustomChange,
  type BillingApplyResult,
  type BillingFailure,
  type BillingPreview,
} from "@/app/admin/(protected)/billing/actions";
import { Button } from "@/components/ui/button";
import {
  describeTarget,
  isFoundersApplied,
  type BillingRule,
} from "@/lib/admin-billing-plan";

export type BillingRowData = {
  email: string;
  shopName: string | null;
  found: boolean;
  rule: BillingRule;
  description: string;
  localAmount: number | null;
  localPlanCode: string | null;
};

const inputClass =
  "w-full rounded-2xl border border-artisan-clay bg-artisan-bone/30 px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta";

function fmt(before: { amount: number | null; runDate: string | null }) {
  return `${before.amount !== null ? `R${before.amount}` : "?"}, next charge ${before.runDate ?? "?"}`;
}

function PreviewSummary({ preview }: { preview: BillingPreview }) {
  return (
    <div className="space-y-1 rounded-2xl border border-artisan-clay bg-artisan-bone/30 p-3 text-xs">
      <p>
        <span className="font-medium text-artisan-sienna">PayFast now:</span>{" "}
        {preview.payfast?.ok
          ? `R${preview.payfast.amount}, next charge ${preview.payfast.runDate} (${preview.payfast.status})`
          : "not available"}
      </p>
      <p>
        <span className="font-medium text-artisan-sienna">Our record:</span>{" "}
        {preview.local.status ?? "none"}, {preview.local.plan_code ?? "no plan"}, R
        {preview.local.amount ?? "?"}, period end{" "}
        {preview.local.current_period_end?.slice(0, 10) ?? "?"}
        {preview.local.status_reason ? ` (${preview.local.status_reason})` : ""}
      </p>
      <p>
        <span className="font-medium text-artisan-sienna">Target:</span>{" "}
        {preview.target ? describeTarget(preview.target) : "none"}
      </p>
      {preview.target?.flag ? (
        <p className="text-amber-700">{preview.target.flag}</p>
      ) : null}
    </div>
  );
}

function ApprovedRow({ row }: { row: BillingRowData }) {
  const [pending, startTransition] = useTransition();
  const [preview, setPreview] = useState<BillingPreview | null>(null);
  const [result, setResult] = useState<BillingApplyResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const alreadyApplied =
    isFoundersApplied({ amount: row.localAmount, plan_code: row.localPlanCode }) ||
    Boolean(result);
  const info = row.rule === "reinstate-6-months";

  function runPreview() {
    setError(null);
    startTransition(async () => {
      const res = await previewApprovedChange(row.email);
      if (res.ok) setPreview(res);
      else setError((res as BillingFailure).error);
    });
  }

  function runApply() {
    if (!preview?.planned) return;
    const after = describeTarget(preview.target!);
    const before = preview.payfast?.ok
      ? `R${preview.payfast.amount}, next charge ${preview.payfast.runDate}`
      : "unknown";
    if (
      !window.confirm(
        `Apply change for ${row.shopName ?? row.email}?\n\nBefore: ${before}\nAfter: ${after}`,
      )
    ) {
      return;
    }
    setError(null);
    startTransition(async () => {
      const res = await applyApprovedChange(row.email);
      if (res.ok) {
        setResult(res);
        setPreview(null);
      } else {
        setError((res as BillingFailure).error);
      }
    });
  }

  return (
    <tr className="border-t border-artisan-clay/60 align-top">
      <td className="px-3 py-3">
        <p className="font-medium text-artisan-sienna">
          {row.shopName ?? (row.found ? "No shop" : "Not found")}
        </p>
        <p className="text-xs text-muted-foreground">{row.email}</p>
      </td>
      <td className="px-3 py-3 text-sm text-muted-foreground">
        {row.description}
      </td>
      <td className="px-3 py-3 text-sm">
        {info ? (
          <p className="text-muted-foreground">
            Needs a new subscription: send the shop a sign-up link; no API
            action.
          </p>
        ) : (
          <div className="space-y-2">
            {alreadyApplied ? (
              <p className="font-medium text-green-700">Applied</p>
            ) : null}
            {!row.found ? (
              <p className="text-red-600">No profile with this email.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                <Button
                  disabled={pending}
                  onClick={runPreview}
                  size="sm"
                  type="button"
                  variant="outline"
                >
                  {pending && !preview ? "Working..." : "Preview"}
                </Button>
                {preview?.planned ? (
                  <Button
                    disabled={pending}
                    onClick={runApply}
                    size="sm"
                    type="button"
                  >
                    Apply
                  </Button>
                ) : null}
              </div>
            )}
            {preview ? <PreviewSummary preview={preview} /> : null}
            {result ? (
              <p className="text-xs text-green-700">
                {fmt(result.before)} {"->"} {fmt(result.after)}
              </p>
            ) : null}
            {error ? <p className="text-xs text-red-600">{error}</p> : null}
          </div>
        )}
      </td>
    </tr>
  );
}

export function ApprovedChangesTable({ rows }: { rows: BillingRowData[] }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead className="text-xs uppercase tracking-wider text-artisan-terracotta">
          <tr>
            <th className="px-3 py-2">Shop</th>
            <th className="px-3 py-2">Change</th>
            <th className="px-3 py-2">Target and actions</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <ApprovedRow key={row.email} row={row} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function CustomChangeForm() {
  const [pending, startTransition] = useTransition();
  const [form, setForm] = useState({
    email: "",
    amount: "",
    runDate: "",
    note: "",
  });
  const [preview, setPreview] = useState<BillingPreview | null>(null);
  const [result, setResult] = useState<BillingApplyResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  function update(key: keyof typeof form, value: string) {
    setForm((prev) => ({ ...prev, [key]: value }));
    setPreview(null);
    setResult(null);
  }

  function runPreview() {
    setError(null);
    setResult(null);
    startTransition(async () => {
      const res = await previewCustomChange(form);
      if (res.ok) setPreview(res);
      else setError((res as BillingFailure).error);
    });
  }

  function runApply() {
    if (!preview) return;
    const before = preview.payfast?.ok
      ? `R${preview.payfast.amount}, next charge ${preview.payfast.runDate}`
      : "unknown";
    const after = `${
      form.amount ? `R${form.amount}` : `R${preview.payfast?.amount ?? "?"}`
    }, next charge ${form.runDate || preview.payfast?.runDate || "?"}`;
    if (
      !window.confirm(
        `Apply change for ${form.email}?\n\nBefore: ${before}\nAfter: ${after}`,
      )
    ) {
      return;
    }
    setError(null);
    startTransition(async () => {
      const res = await applyCustomChange(form);
      if (res.ok) {
        setResult(res);
        setPreview(null);
      } else {
        setError((res as BillingFailure).error);
      }
    });
  }

  return (
    <div className="space-y-3">
      <div className="grid gap-3 md:grid-cols-2">
        <input
          className={inputClass}
          onChange={(e) => update("email", e.target.value)}
          placeholder="Shop email"
          type="email"
          value={form.email}
        />
        <input
          className={inputClass}
          min="0"
          onChange={(e) => update("amount", e.target.value)}
          placeholder="New amount in rands (optional)"
          step="0.01"
          type="number"
          value={form.amount}
        />
        <input
          className={inputClass}
          onChange={(e) => update("runDate", e.target.value)}
          type="date"
          value={form.runDate}
        />
        <input
          className={inputClass}
          onChange={(e) => update("note", e.target.value)}
          placeholder="Note"
          value={form.note}
        />
      </div>
      <div className="flex flex-wrap gap-2">
        <Button disabled={pending} onClick={runPreview} type="button" variant="outline">
          {pending && !preview ? "Working..." : "Preview"}
        </Button>
        {preview ? (
          <Button disabled={pending} onClick={runApply} type="button">
            Apply
          </Button>
        ) : null}
      </div>
      {preview ? <PreviewSummary preview={preview} /> : null}
      {result ? (
        <p className="text-sm text-green-700">
          {result.email}: {fmt(result.before)} {"->"} {fmt(result.after)}
        </p>
      ) : null}
      {error ? <p className="text-sm text-red-600">{error}</p> : null}
    </div>
  );
}
