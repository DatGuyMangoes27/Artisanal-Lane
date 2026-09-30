"use server";

import { requireAdminSession } from "@/lib/admin-auth";
import {
  APPROVED_CHANGES,
  DEFAULT_APPLY_NOTE,
  FOUNDERS_PLAN_CODE,
  computeTarget,
  validateCustomChange,
  type BillingRule,
  type BillingTarget,
} from "@/lib/admin-billing-plan";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient as createServerClient } from "@/lib/supabase/server";

type LocalSub = {
  status: string | null;
  plan_code: string | null;
  amount: number | string | null;
  current_period_end: string | null;
  status_reason: string | null;
};

type PayfastSub = {
  ok: boolean;
  amount: number | null;
  runDate: string | null;
  status: string | null;
};

export type BillingPreview = {
  ok: true;
  email: string;
  vendorId: string;
  local: LocalSub;
  payfast: PayfastSub;
  startedAt: string | null;
  target: BillingTarget | null;
  /** Payload that Apply will send (amount in rands, runDate/planCode optional). */
  planned: { amount?: number; runDate?: string; planCode?: string } | null;
};

export type BillingApplyResult = {
  ok: true;
  email: string;
  before: { amount: number | null; runDate: string | null };
  after: { amount: number | null; runDate: string | null };
};

export type BillingFailure = { ok: false; error: string };

function today() {
  return new Date().toISOString().slice(0, 10);
}

function fail(error: unknown, fallback: string): BillingFailure {
  return {
    ok: false,
    error: error instanceof Error ? error.message : fallback,
  };
}

async function findVendorId(email: string): Promise<string> {
  const admin = createAdminClient();
  const { data, error } = await admin
    .from("profiles")
    .select("id")
    .ilike("email", email)
    .limit(2);
  if (error) throw new Error(`Profile lookup failed: ${error.message}`);
  if (!data || data.length === 0) {
    throw new Error(`No profile found for ${email}.`);
  }
  if (data.length > 1) {
    throw new Error(`More than one profile matches ${email}.`);
  }
  return data[0].id as string;
}

async function invokeBilling<T>(body: Record<string, unknown>): Promise<T> {
  const supabase = await createServerClient();
  const result = await supabase.functions.invoke("admin-subscription-billing", {
    body,
  });
  if (result.error) {
    let detail = result.error.message;
    const context = (result.error as { context?: unknown }).context;
    if (context && typeof (context as Response).json === "function") {
      try {
        const parsed = (await (context as Response).json()) as {
          error?: string;
        };
        if (parsed?.error) detail = parsed.error;
      } catch {
        // keep generic message
      }
    }
    throw new Error(detail);
  }
  const data = result.data as { error?: string } | null;
  if (data?.error) throw new Error(data.error);
  return data as T;
}

async function loadStartedAt(vendorId: string): Promise<string | null> {
  const admin = createAdminClient();
  const { data } = await admin
    .from("vendor_subscriptions")
    .select("started_at")
    .eq("vendor_id", vendorId)
    .maybeSingle<{ started_at: string | null }>();
  return data?.started_at ?? null;
}

async function previewInternal(
  email: string,
  rule: BillingRule | null,
  custom: { amount?: number; runDate?: string } | null,
): Promise<BillingPreview> {
  const vendorId = await findVendorId(email);
  const response = await invokeBilling<{ local: LocalSub; payfast: PayfastSub }>({
    action: "preview",
    vendorId,
  });
  const startedAt = await loadStartedAt(vendorId);

  let target: BillingTarget | null = null;
  let planned: BillingPreview["planned"] = null;
  if (rule) {
    if (!response.payfast?.ok) {
      throw new Error("PayFast did not return a usable subscription.");
    }
    target = computeTarget(rule, {
      payfastRunDate: response.payfast.runDate,
      startedAt,
      today: today(),
    });
    if (target) {
      planned = {
        amount: target.amount,
        ...(target.runDate ? { runDate: target.runDate } : {}),
        planCode: FOUNDERS_PLAN_CODE,
      };
    }
  } else if (custom) {
    planned = { ...custom };
    target = {
      amount: custom.amount ?? Number(response.payfast?.amount ?? 0),
      runDate: custom.runDate ?? null,
      flag: null,
    };
  }

  return {
    ok: true,
    email,
    vendorId,
    local: response.local,
    payfast: response.payfast,
    startedAt,
    target,
    planned,
  };
}

async function applyInternal(
  preview: BillingPreview,
  note: string,
): Promise<BillingApplyResult> {
  if (!preview.planned) throw new Error("Nothing to apply for this row.");
  const response = await invokeBilling<{
    ok: boolean;
    before: { amount: number | null; runDate: string | null };
    after: { amount: number | null; runDate: string | null };
  }>({
    action: "apply",
    vendorId: preview.vendorId,
    ...preview.planned,
    note,
  });
  return {
    ok: true,
    email: preview.email,
    before: response.before,
    after: response.after,
  };
}

function findApproved(email: string) {
  const row = APPROVED_CHANGES.find((c) => c.email === email.toLowerCase());
  if (!row) throw new Error(`${email} is not in the approved list.`);
  return row;
}

export async function previewApprovedChange(
  email: string,
): Promise<BillingPreview | BillingFailure> {
  try {
    await requireAdminSession();
    const row = findApproved(email);
    if (row.rule === "reinstate-6-months") {
      throw new Error("This row has no API action.");
    }
    return await previewInternal(row.email, row.rule, null);
  } catch (error) {
    return fail(error, "Unable to preview.");
  }
}

// Apply always recomputes the target server-side from a fresh preview.
export async function applyApprovedChange(
  email: string,
): Promise<BillingApplyResult | BillingFailure> {
  try {
    await requireAdminSession();
    const row = findApproved(email);
    if (row.rule === "reinstate-6-months") {
      throw new Error("This row has no API action.");
    }
    const preview = await previewInternal(row.email, row.rule, null);
    return await applyInternal(preview, DEFAULT_APPLY_NOTE);
  } catch (error) {
    return fail(error, "Unable to apply.");
  }
}

type CustomInput = {
  email: string;
  amount: string;
  runDate: string;
  note: string;
};

export async function previewCustomChange(
  input: CustomInput,
): Promise<BillingPreview | BillingFailure> {
  try {
    await requireAdminSession();
    const checked = validateCustomChange(input, today());
    if (!checked.ok) throw new Error(checked.error);
    const { email, amount, runDate } = checked.value;
    return await previewInternal(email, null, { amount, runDate });
  } catch (error) {
    return fail(error, "Unable to preview.");
  }
}

export async function applyCustomChange(
  input: CustomInput,
): Promise<BillingApplyResult | BillingFailure> {
  try {
    await requireAdminSession();
    const checked = validateCustomChange(input, today());
    if (!checked.ok) throw new Error(checked.error);
    const { email, amount, runDate, note } = checked.value;
    const preview = await previewInternal(email, null, { amount, runDate });
    return await applyInternal(preview, note || "Custom billing change (admin)");
  } catch (error) {
    return fail(error, "Unable to apply.");
  }
}
