export type MarketingContact = {
  email: string | null;
  phone: string | null;
  name: string | null;
  source: string;
  consentedAt: string;
};

function csvCell(value: string | null | undefined) {
  const text = (value ?? "").replace(/\r?\n/g, " ");
  // Stop spreadsheets reading a name as a formula.
  const safe = /^[=+\-@]/.test(text) ? `'${text}` : text;
  return /[",]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
}

/** CSV with the column names Meta Custom Audiences recognise. */
export function marketingContactsCsv(contacts: MarketingContact[]) {
  const lines = ["email,phone,fn,source,consented_at"];
  for (const c of contacts) {
    const firstName = (c.name ?? "").trim().split(/\s+/)[0] ?? "";
    lines.push([c.email, c.phone, firstName, c.source, c.consentedAt].map(csvCell).join(","));
  }
  return lines.join("\n") + "\n";
}
