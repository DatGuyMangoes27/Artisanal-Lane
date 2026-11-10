import "server-only";

import { createAdminClient } from "@/lib/supabase/admin";

import { type MarketingContact } from "./marketing-contacts-csv";

export { marketingContactsCsv, type MarketingContact } from "./marketing-contacts-csv";

/**
 * Everyone who agreed to hear from Artisan Lane and hasn't unsubscribed:
 * buyers who ticked "Keep me posted" at checkout, plus newsletter sign-ups.
 * One row per email (checkout details win).
 */
export async function listMarketingContacts(): Promise<MarketingContact[]> {
  const admin = createAdminClient();
  const [checkout, newsletter] = await Promise.all([
    admin
      .from("marketing_contacts")
      .select("email, phone, display_name, source, consented_at")
      .is("unsubscribed_at", null)
      .order("consented_at", { ascending: false }),
    admin
      .from("newsletter_subscribers")
      .select("email, source, subscribed_at")
      .is("unsubscribed_at", null)
      .order("subscribed_at", { ascending: false }),
  ]);

  const byEmail = new Map<string, MarketingContact>();
  const add = (contact: MarketingContact) => {
    const key = (contact.email ?? contact.phone ?? "").trim().toLowerCase();
    if (!key || byEmail.has(key)) return;
    byEmail.set(key, contact);
  };
  for (const row of checkout.data ?? []) {
    add({
      email: row.email,
      phone: row.phone,
      name: row.display_name,
      source: row.source,
      consentedAt: row.consented_at,
    });
  }
  for (const row of newsletter.data ?? []) {
    add({
      email: row.email,
      phone: null,
      name: null,
      source: row.source ?? "newsletter",
      consentedAt: row.subscribed_at,
    });
  }
  return [...byEmail.values()];
}
