import { createHash } from "node:crypto";

import { isPayFastCancellationSuccess } from "./subscription-cancellation.mjs";

const PAYFAST_SANDBOX = (Deno.env.get("PAYFAST_SANDBOX") ?? "false") === "true";

const PAYFAST_PROCESS_URL = PAYFAST_SANDBOX
  ? "https://sandbox.payfast.co.za/eng/process"
  : "https://www.payfast.co.za/eng/process";

const PAYFAST_VALIDATE_URL = PAYFAST_SANDBOX
  ? "https://sandbox.payfast.co.za/eng/query/validate"
  : "https://www.payfast.co.za/eng/query/validate";

function requireEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function encodePayFastValue(value: string) {
  return encodeURIComponent(value)
    .replace(/%20/g, "+")
    .replace(/!/g, "%21")
    .replace(/~/g, "%7E")
    .replace(/\*/g, "%2A")
    .replace(/'/g, "%27")
    .replace(/\(/g, "%28")
    .replace(/\)/g, "%29");
}

function normalizeValue(value: string | number | null | undefined) {
  if (value == null) return null;
  const stringValue = String(value).trim();
  return stringValue.length > 0 ? stringValue : null;
}

function buildSignaturePayload(entries: Array<[string, string]>, passphrase?: string) {
  const parts = entries
    .filter(([key]) => key !== "signature")
    .map(([key, value]) => `${key}=${encodePayFastValue(value)}`);

  const normalizedPassphrase = normalizeValue(passphrase);
  if (normalizedPassphrase != null) {
    parts.push(`passphrase=${encodePayFastValue(normalizedPassphrase)}`);
  }

  return parts.join("&");
}

function createMd5Hash(input: string) {
  return createHash("md5").update(input).digest("hex");
}

function addMonths(date: Date, months: number) {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth();
  const day = date.getUTCDate();
  const targetMonthIndex = month + months;
  const targetYear = year + Math.floor(targetMonthIndex / 12);
  const normalizedMonth = ((targetMonthIndex % 12) + 12) % 12;
  const lastDayOfTargetMonth = new Date(Date.UTC(targetYear, normalizedMonth + 1, 0)).getUTCDate();
  return new Date(Date.UTC(
    targetYear,
    normalizedMonth,
    Math.min(day, lastDayOfTargetMonth),
    date.getUTCHours(),
    date.getUTCMinutes(),
    date.getUTCSeconds(),
    date.getUTCMilliseconds(),
  ));
}

function splitDisplayName(displayName: string) {
  const clean = displayName.trim() || "Artisan Lane";
  const parts = clean.split(/\s+/).filter(Boolean);
  return {
    firstName: parts[0] ?? "Artisan",
    lastName: parts.length > 1 ? parts.slice(1).join(" ") : "Lane",
  };
}

export function getPayFastConfig() {
  return {
    merchantId: requireEnv("PAYFAST_MERCHANT_ID"),
    merchantKey: requireEnv("PAYFAST_MERCHANT_KEY"),
    passphrase: normalizeValue(Deno.env.get("PAYFAST_PASSPHRASE")),
    processUrl: PAYFAST_PROCESS_URL,
    validateUrl: PAYFAST_VALIDATE_URL,
    sandbox: PAYFAST_SANDBOX,
  };
}

export function buildPayFastSignature(
  entries: Array<[string, string]>,
  passphrase?: string,
) {
  return createMd5Hash(buildSignaturePayload(entries, passphrase));
}

export function parsePayFastFormEncoded(rawBody: string) {
  return new URLSearchParams(rawBody);
}

export function buildPayFastSubscriptionCheckoutUrl(input: {
  amount: number;
  recurringAmount?: number;
  itemName: string;
  itemDescription: string;
  reference: string;
  vendorId: string;
  checkoutReference: string;
  email: string;
  displayName: string;
  returnUrl: string;
  cancelUrl: string;
  notifyUrl: string;
  /** Free months before the first recurring charge (default 2). */
  freeMonths?: number;
}) {
  const config = getPayFastConfig();
  const { firstName, lastName } = splitDisplayName(input.displayName);
  const billingDate = addMonths(new Date(), input.freeMonths ?? 2)
    .toISOString()
    .slice(0, 10);
  const entries: Array<[string, string]> = [
    ["merchant_id", config.merchantId],
    ["merchant_key", config.merchantKey],
    ["return_url", input.returnUrl],
    ["cancel_url", input.cancelUrl],
    ["notify_url", input.notifyUrl],
    ["name_first", firstName],
    ["name_last", lastName],
    ["email_address", input.email],
    ["m_payment_id", input.reference],
    ["amount", input.amount.toFixed(2)],
    ["item_name", input.itemName],
    ["item_description", input.itemDescription],
    ["custom_str1", input.vendorId],
    ["custom_str2", input.checkoutReference],
    ["subscription_type", "1"],
    ["billing_date", billingDate],
    ...(input.recurringAmount != null
      ? [["recurring_amount", input.recurringAmount.toFixed(2)] as [string, string]]
      : []),
    ["frequency", "3"],
    ["cycles", "0"],
  ];

  const payload = buildSignaturePayload(entries, config.passphrase ?? undefined);
  const signature = createMd5Hash(payload);

  return `${config.processUrl}?${payload}&signature=${signature}`;
}

export function buildPayFastOnceOffCheckoutUrl(input: {
  amount: number;
  itemName: string;
  itemDescription: string;
  reference: string;
  email: string;
  displayName: string;
  returnUrl: string;
  cancelUrl: string;
  notifyUrl: string;
  customStrings?: Array<string | null | undefined>;
}) {
  const config = getPayFastConfig();
  const { firstName, lastName } = splitDisplayName(input.displayName);
  const entries: Array<[string, string]> = [
    ["merchant_id", config.merchantId],
    ["merchant_key", config.merchantKey],
    ["return_url", input.returnUrl],
    ["cancel_url", input.cancelUrl],
    ["notify_url", input.notifyUrl],
    ["name_first", firstName],
    ["name_last", lastName],
    ["email_address", input.email],
    ["m_payment_id", input.reference],
    ["amount", input.amount.toFixed(2)],
    ["item_name", input.itemName],
    ["item_description", input.itemDescription],
  ];

  (input.customStrings ?? []).slice(0, 5).forEach((value, index) => {
    const normalized = normalizeValue(value);
    if (normalized != null) {
      entries.push([`custom_str${index + 1}`, normalized]);
    }
  });

  const payload = buildSignaturePayload(entries, config.passphrase ?? undefined);
  const signature = createMd5Hash(payload);

  return `${config.processUrl}?${payload}&signature=${signature}`;
}

export function verifyPayFastItnSignatureFromRaw(rawBody: string, _passphrase?: string | null) {
  const params = parsePayFastFormEncoded(rawBody);
  let providedSignature: string | null = null;
  const entries: Array<[string, string]> = [];

  for (const [key, value] of params.entries()) {
    if (key === "signature") {
      providedSignature = value;
      break;
    }

    entries.push([key, value]);
  }

  const unsignedSigningString = buildSignaturePayload(entries);
  const unsignedExpectedSignature = createMd5Hash(unsignedSigningString);
  const passphraseSigningString = buildSignaturePayload(entries, _passphrase ?? undefined);
  const passphraseExpectedSignature = createMd5Hash(passphraseSigningString);
  const matchesUnsigned = providedSignature != null &&
    providedSignature === unsignedExpectedSignature;
  const matchesPassphrase = providedSignature != null &&
    providedSignature === passphraseExpectedSignature;
  const matchedWithPassphrase = matchesPassphrase && !matchesUnsigned;

  return {
    providedSignature,
    expectedSignature: matchedWithPassphrase
      ? passphraseExpectedSignature
      : unsignedExpectedSignature,
    matches: matchesUnsigned || matchesPassphrase,
    signingString: matchedWithPassphrase
      ? passphraseSigningString
      : unsignedSigningString,
  };
}

export async function callPayFastValidate(validateUrl: string, rawBody: string) {
  try {
    const response = await fetch(validateUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: rawBody,
    });
    const text = await response.text();
    return {
      ok: response.ok && text.trim().toUpperCase() === "VALID",
      status: response.status,
      body: text,
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      body: error instanceof Error ? error.message : "validate_fetch_failed",
    };
  }
}

export async function verifyPayFastItn(rawBody: string) {
  const config = getPayFastConfig();
  const params = parsePayFastFormEncoded(rawBody);
  const signatureCheck = verifyPayFastItnSignatureFromRaw(rawBody, config.passphrase);

  if (!signatureCheck.matches) {
    throw new Error("Invalid PayFast signature.");
  }

  const validate = await callPayFastValidate(config.validateUrl, rawBody);
  if (!validate.ok) {
    throw new Error("PayFast ITN validation failed.");
  }

  return params;
}

const PAYFAST_API_BASE = "https://api.payfast.co.za";

export function payFastApiTimestamp(date: Date = new Date()) {
  return date.toISOString().replace(/\.\d{3}Z$/, "+00:00");
}

function buildPayFastApiSignature(
  data: Record<string, string>,
  passphrase: string | null | undefined,
) {
  const combined: Record<string, string> = { ...data };
  const normalizedPassphrase = normalizeValue(passphrase ?? undefined);
  if (normalizedPassphrase != null) {
    combined.passphrase = normalizedPassphrase;
  }

  const sortedKeys = Object.keys(combined).sort();
  const parts = sortedKeys.map(
    (key) => `${key}=${encodePayFastValue(combined[key] ?? "")}`,
  );
  return {
    signature: createMd5Hash(parts.join("&")),
    signingString: parts.join("&"),
  };
}

export async function cancelPayFastSubscription(token: string) {
  const config = getPayFastConfig();
  const timestamp = payFastApiTimestamp();
  const apiHeaders: Record<string, string> = {
    "merchant-id": config.merchantId,
    version: "v1",
    timestamp,
  };
  const { signature, signingString } = buildPayFastApiSignature(
    apiHeaders,
    config.passphrase,
  );

  const url = config.sandbox
    ? `${PAYFAST_API_BASE}/subscriptions/${encodeURIComponent(token)}/cancel?testing=true`
    : `${PAYFAST_API_BASE}/subscriptions/${encodeURIComponent(token)}/cancel`;

  console.log("cancelPayFastSubscription request", {
    sandbox: config.sandbox,
    timestamp,
    signingStringLength: signingString.length,
  });

  const response = await fetch(url, {
    method: "PUT",
    headers: {
      ...apiHeaders,
      signature,
      "Content-Type": "application/json",
      accept: "application/json",
    },
  });

  const bodyText = await response.text();
  let bodyJson: unknown = null;
  try {
    bodyJson = bodyText.length > 0 ? JSON.parse(bodyText) : null;
  } catch {
    bodyJson = null;
  }

  return {
    ok: isPayFastCancellationSuccess(response.ok, bodyJson),
    status: response.status,
    body: bodyJson ?? bodyText,
  };
}

export function mapPayFastSubscriptionStatus(paymentStatus: string | null | undefined) {
  switch ((paymentStatus ?? "").toUpperCase()) {
    case "COMPLETE":
      return "active";
    case "CANCELLED":
      return "cancelled";
    case "FAILED":
      return "past_due";
    default:
      return "inactive";
  }
}

/**
 * Period end after a successful renewal payment: one month after the later of
 * the current period end and now. Extending a long-lapsed period end (e.g. a
 * subscription whose payments failed for months) from its old date would leave
 * a paying artisan still marked as overdue.
 */
export function nextSubscriptionPeriodEnd(
  fromIso?: string | null,
  now: Date = new Date(),
) {
  const periodEnd = fromIso != null ? new Date(fromIso) : null;
  const baseDate = periodEnd != null && !Number.isNaN(periodEnd.getTime()) &&
      periodEnd > now
    ? periodEnd
    : now;
  return addMonths(baseDate, 1).toISOString();
}

/**
 * Period end for the initial R0 sign-up ITN. The PayFast subscription is
 * created with billing_date two months out ("first two months free"), so the
 * vendor's access must also run for two months until the first real charge.
 */
export function initialSubscriptionPeriodEnd(
  fromIso?: string | null,
  freeMonths = 2,
) {
  const baseDate = fromIso != null ? new Date(fromIso) : new Date();
  return addMonths(baseDate, freeMonths).toISOString();
}

/** Adds whole calendar months, clamping to the target month's last day. */
export function addSubscriptionMonths(fromIso: string, months: number) {
  return addMonths(new Date(fromIso), months).toISOString().slice(0, 10);
}

export type PayFastSubscriptionDetails = {
  ok: boolean;
  status: number;
  amountCents: number | null;
  runDate: string | null;
  statusText: string | null;
  body: unknown;
};

/** PayFast update body: amount in cents and the next charge date. */
export function buildPayFastUpdateBody(input: {
  amountRands?: number | null;
  runDate?: string | null;
}) {
  const body: Record<string, string> = {};
  if (input.amountRands != null) {
    if (!Number.isFinite(input.amountRands) || input.amountRands <= 0) {
      throw new Error("Amount must be a positive number of rands.");
    }
    body.amount = String(Math.round(input.amountRands * 100));
  }
  if (input.runDate != null) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.runDate)) {
      throw new Error("Next charge date must be YYYY-MM-DD.");
    }
    // PayFast's update endpoint validates the date under both names: sending
    // only run_date fails "next run is required", only next_run fails "run
    // date is required" (seen live, Oct 2026). Send both.
    body.run_date = input.runDate;
    body.next_run = input.runDate;
  }
  if (Object.keys(body).length === 0) {
    throw new Error("Nothing to update.");
  }
  return body;
}

async function callPayFastSubscriptionApi(
  token: string,
  action: "fetch" | "update",
  body?: Record<string, string>,
): Promise<PayFastSubscriptionDetails> {
  const config = getPayFastConfig();
  const timestamp = payFastApiTimestamp();
  const apiHeaders: Record<string, string> = {
    "merchant-id": config.merchantId,
    version: "v1",
    timestamp,
  };
  // PayFast signs header and body variables together.
  const { signature } = buildPayFastApiSignature(
    { ...apiHeaders, ...(body ?? {}) },
    config.passphrase,
  );
  const path = `${PAYFAST_API_BASE}/subscriptions/${encodeURIComponent(token)}/${action}`;
  const response = await fetch(config.sandbox ? `${path}?testing=true` : path, {
    method: action === "fetch" ? "GET" : "PATCH",
    headers: {
      ...apiHeaders,
      signature,
      "Content-Type": "application/json",
      accept: "application/json",
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json: unknown = null;
  try {
    json = text.length > 0 ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  const data = (json as { data?: { response?: Record<string, unknown> } } | null)
    ?.data?.response ?? null;
  const amount = data?.amount;
  const runDate = data?.run_date;
  return {
    ok: response.ok &&
      (json as { status?: string } | null)?.status !== "failed",
    status: response.status,
    amountCents: typeof amount === "number"
      ? amount
      : typeof amount === "string" && amount.trim() !== ""
      ? Number(amount)
      : null,
    runDate: typeof runDate === "string" ? runDate.slice(0, 10) : null,
    statusText: typeof data?.status_text === "string" ? data.status_text : null,
    body: json ?? text,
  };
}

/** Reads a subscription's real amount and next charge date from PayFast. */
export function fetchPayFastSubscription(token: string) {
  return callPayFastSubscriptionApi(token, "fetch");
}

/** Changes a subscription's recurring amount and/or next charge date. */
export function updatePayFastSubscription(
  token: string,
  input: { amountRands?: number | null; runDate?: string | null },
) {
  return callPayFastSubscriptionApi(token, "update", buildPayFastUpdateBody(input));
}
