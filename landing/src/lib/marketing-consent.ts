// The wording buyers agree to when they tick "Keep me posted" at checkout.
// Stored with each consent, so change the version when the text changes.
export const MARKETING_CONSENT_VERSION = "2026-11";
export const MARKETING_CONSENT_TEXT =
  "Keep me posted: Artisan Lane may email, SMS or WhatsApp me about new pieces, offers and my orders. I can unsubscribe at any time.";

type RpcClient = {
  rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ error: unknown }>;
};

/** Records a ticked "Keep me posted" box. Never blocks checkout. */
export async function recordMarketingConsent(supabase: RpcClient, phone: string) {
  try {
    await supabase.rpc("set_marketing_consent", {
      p_opt_in: true,
      p_phone: phone,
      p_source: "web-checkout",
      p_consent_text: MARKETING_CONSENT_TEXT,
      p_consent_version: MARKETING_CONSENT_VERSION,
    });
  } catch {
    // Consent is a bonus; the order matters more.
  }
}
