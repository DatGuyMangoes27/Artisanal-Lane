// Pure helpers and the approved-changes list for the admin Billing page.
// No network or database access lives here.

export type BillingRule =
  | "r199-from-next"
  | "free-month-then-r199"
  | "one-month-from-signup-then-r199"
  | "reinstate-6-months";

export const FOUNDERS_PLAN_CODE = "founders-199";
export const FOUNDERS_AMOUNT = 199;
export const DEFAULT_APPLY_NOTE = "Founders R199 change (email 29 Sep)";

export type ApprovedChange = {
  email: string;
  rule: BillingRule;
  description: string;
};

export const RULE_DESCRIPTIONS: Record<BillingRule, string> = {
  "r199-from-next": "R199 from the next charge; keep the current charge date",
  "free-month-then-r199":
    "Free month (charge date moves one month later), then R199/month",
  "one-month-from-signup-then-r199":
    "First charge one month after sign-up, then R199/month",
  "reinstate-6-months":
    "Reinstate for 6 months: needs a new subscription (no API action)",
};

function rows(rule: BillingRule, emails: string[], note?: string): ApprovedChange[] {
  return emails.map((email) => ({
    email,
    rule,
    description: note
      ? `${RULE_DESCRIPTIONS[rule]} (${note})`
      : RULE_DESCRIPTIONS[rule],
  }));
}

// Shop names are looked up at runtime (shops.vendor_id -> profiles.id).
export const APPROVED_CHANGES: ApprovedChange[] = [
  ...rows(
    "free-month-then-r199",
    [
      "knitbynic1459@gmail.com",
      "meljdewinnaar@gmail.com",
      "suzette@boshoffandowl.co.za",
    ],
    "charged R349 on 30 Sep",
  ),
  ...rows("free-month-then-r199", [
    "h.of.clay@gmail.com",
    "pinupshs@gmail.com",
    "carlisager@gmail.com",
  ]),
  ...rows("r199-from-next", [
    "lumin.loomatelier@gmail.com",
    "handfordmz@gmail.com",
    "cmudau74@gmail.com",
    "stitchesandtalesbhm@gmail.com",
    "makishikwambana@gmail.com",
    "carienkoekemoer81@gmail.com",
    "daphneymilambo@gmail.com",
    "ruthsuter84@gmail.com",
    "worokani@gmail.com",
    "vivian@elysian.net.za",
    "hendricksginette2727@gmail.com",
    "care@xhozucan.com",
    "jaquelineswanepoel67@gmail.com",
    "eloisegailrobbertze@gmail.com",
    "tammeyfreer@gmail.com",
    "tanyauys@worldonline.co.za",
    "meryl@merylsart.co.za",
  ]),
  ...rows(
    "r199-from-next",
    [
      "justartsa01@gmail.com",
      "stanley.gv27@gmail.com",
      "shopupswing.sa@gmail.com",
      "oohlalocs329@gmail.com",
      "snyman.timber@gmail.com",
      "santana@clickboogie.com",
      "ericaseptember@gmail.com",
      "alegriahandcrafted@gmail.com",
      "dropsofnectar.sales@gmail.com",
      "shirleymlangton@gmail.com",
      "mumtaz@amanibotanica.com",
      "clarezarothwell@gmail.com",
      "denniseheather16@gmail.com",
    ],
    "signed up before the founders offer went live",
  ),
  ...rows(
    "r199-from-next",
    [
      "craftreworx@gmail.com",
      "lulu.vermeulen@gmail.com",
      "castfurniture@outlook.com",
      "hellostarlingandcrow@gmail.com",
      "keetgretha@gmail.com",
      "kungeka@pureapparel.co.za",
      "nickyhendricks04@gmail.com",
      "nomagugupn@gmail.com",
      "noorjehanhassen@hotmail.com",
      "soulafrican@gmail.com",
    ],
    "everyone moves to R199",
  ),
  ...rows("one-month-from-signup-then-r199", ["astridwood52@gmail.com"]),
  ...rows(
    "one-month-from-signup-then-r199",
    ["salessweetsavorcandles@gmail.com"],
    "re-subscribed, no extra free period",
  ),
  ...rows("reinstate-6-months", ["cinkeacreations@icloud.com"]),
];

// Everyone moves to R199 now; kept empty so the page can show a note.
export const NO_CHANGE_STAY_R349: string[] = [];

// ---- date helpers ----

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

export function parseIsoDate(value: string): Date | null {
  const match = ISO_DATE.exec(value);
  if (!match) return null;
  const y = Number(match[1]);
  const m = Number(match[2]);
  const d = Number(match[3]);
  const date = new Date(Date.UTC(y, m - 1, d));
  if (
    date.getUTCFullYear() !== y ||
    date.getUTCMonth() !== m - 1 ||
    date.getUTCDate() !== d
  ) {
    return null;
  }
  return date;
}

export function formatIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** Adds calendar months to a YYYY-MM-DD date, clamped to month end (31 Jan + 1 = 28/29 Feb). */
export function addMonthsClamped(isoDate: string, months: number): string {
  const date = parseIsoDate(isoDate.slice(0, 10));
  if (!date) throw new Error(`Invalid date: ${isoDate}`);
  const day = date.getUTCDate();
  const target = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1),
  );
  const lastDay = new Date(
    Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0),
  ).getUTCDate();
  target.setUTCDate(Math.min(day, lastDay));
  return formatIsoDate(target);
}

// ---- target computation ----

export type BillingTarget = {
  amount: number;
  /** null means keep PayFast's current run date. */
  runDate: string | null;
  flag: string | null;
};

export type TargetInputs = {
  payfastRunDate: string | null;
  startedAt: string | null;
  today: string; // YYYY-MM-DD
};

export function computeTarget(
  rule: BillingRule,
  inputs: TargetInputs,
): BillingTarget | null {
  switch (rule) {
    case "r199-from-next":
      return { amount: FOUNDERS_AMOUNT, runDate: null, flag: null };
    case "free-month-then-r199": {
      if (!inputs.payfastRunDate) {
        throw new Error("PayFast run date is required for this rule.");
      }
      return {
        amount: FOUNDERS_AMOUNT,
        runDate: addMonthsClamped(inputs.payfastRunDate, 1),
        flag: null,
      };
    }
    case "one-month-from-signup-then-r199": {
      if (!inputs.startedAt) {
        throw new Error("No started_at on the local subscription.");
      }
      const candidate = addMonthsClamped(inputs.startedAt.slice(0, 10), 1);
      if (candidate > inputs.today) {
        return { amount: FOUNDERS_AMOUNT, runDate: candidate, flag: null };
      }
      return {
        amount: FOUNDERS_AMOUNT,
        runDate: null,
        flag: `Sign-up + 1 month (${candidate}) is not in the future; keeping PayFast's current run date.`,
      };
    }
    case "reinstate-6-months":
      return null;
  }
}

export function describeTarget(target: BillingTarget): string {
  return `R${target.amount}${
    target.runDate ? `, next charge ${target.runDate}` : ", charge date unchanged"
  }`;
}

// ---- validation ----

export type CustomChangeInput = {
  email: string;
  amount: string;
  runDate: string;
  note: string;
};

export type CustomChangeValidation =
  | {
      ok: true;
      value: { email: string; amount?: number; runDate?: string; note: string };
    }
  | { ok: false; error: string };

export function validateCustomChange(
  input: CustomChangeInput,
  today: string,
): CustomChangeValidation {
  const email = input.email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, error: "Enter a valid shop email." };
  }
  const amountText = input.amount.trim();
  const runDate = input.runDate.trim();
  if (!amountText && !runDate) {
    return { ok: false, error: "Enter a new amount, a next charge date, or both." };
  }
  let amount: number | undefined;
  if (amountText) {
    amount = Number(amountText);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 10000) {
      return { ok: false, error: "Amount must be a positive number of rands." };
    }
    amount = Math.round(amount * 100) / 100;
  }
  if (runDate) {
    if (!parseIsoDate(runDate)) {
      return { ok: false, error: "Next charge date must be YYYY-MM-DD." };
    }
    if (runDate <= today) {
      return { ok: false, error: "Next charge date must be in the future." };
    }
  }
  return {
    ok: true,
    value: {
      email,
      ...(amount !== undefined ? { amount } : {}),
      ...(runDate ? { runDate } : {}),
      note: input.note.trim(),
    },
  };
}

export function isFoundersApplied(local: {
  amount?: number | string | null;
  plan_code?: string | null;
}): boolean {
  return (
    Number(local.amount) === FOUNDERS_AMOUNT &&
    local.plan_code === FOUNDERS_PLAN_CODE
  );
}
