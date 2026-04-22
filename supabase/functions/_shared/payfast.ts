import { createHash } from "node:crypto";

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
}) {
  const config = getPayFastConfig();
  const { firstName, lastName } = splitDisplayName(input.displayName);
  const billingDate = addMonths(new Date(), 1).toISOString().slice(0, 10);
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

export function verifyPayFastItnSignatureFromRaw(rawBody: string, passphrase?: string | null) {
  const segments = rawBody.split("&").filter((segment) => segment.length > 0);
  let providedSignature: string | null = null;
  const kept: string[] = [];

  for (const segment of segments) {
    const eqIndex = segment.indexOf("=");
    const key = eqIndex === -1 ? segment : segment.slice(0, eqIndex);
    if (key === "signature") {
      providedSignature = eqIndex === -1 ? "" : segment.slice(eqIndex + 1);
      continue;
    }
    kept.push(segment);
  }

  let signingString = kept.join("&");
  const normalizedPassphrase = normalizeValue(passphrase ?? undefined);
  if (normalizedPassphrase != null) {
    signingString = signingString.length > 0
      ? `${signingString}&passphrase=${encodePayFastValue(normalizedPassphrase)}`
      : `passphrase=${encodePayFastValue(normalizedPassphrase)}`;
  }

  const expectedSignature = createMd5Hash(signingString);
  return {
    providedSignature,
    expectedSignature,
    matches: providedSignature != null && providedSignature === expectedSignature,
    signingString,
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

function payFastApiTimestamp(date: Date = new Date()) {
  return date.toISOString().split(".")[0];
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
    url,
    apiHeaders,
    signature,
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
    ok: response.ok,
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
    case "PENDING":
      return "pending";
    default:
      return "pending";
  }
}

export function nextSubscriptionPeriodEnd(fromIso?: string | null) {
  const baseDate = fromIso != null ? new Date(fromIso) : new Date();
  return addMonths(baseDate, 1).toISOString();
}
