import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { EmailUpdatesForm } from "@/components/marketplace/email-updates-form";

export default async function EmailUpdatesPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/stay-updated");
  const preference = user.user_metadata?.artisan_lane_email_updates;
  return <><MarketplaceHeader /><main className="mx-auto max-w-2xl px-5 py-16">
    <Link href="/account" className="text-sm underline">Back to my account</Link>
    <h1 className="mt-6 font-serif text-4xl">Stay <span className="gradient-text italic">in the loop</span></h1>
    <p className="mt-4 text-muted-foreground">Choose whether to receive promotional updates at {user.email}.</p>
    <EmailUpdatesForm enabled={preference?.enabled === true && preference.email === user.email} />
    <Link href="/privacy" className="mt-6 inline-block text-sm underline">How we use your information</Link>
  </main></>;
}
