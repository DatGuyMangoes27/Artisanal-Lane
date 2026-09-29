import { PublicNewsletterForm } from "@/components/marketplace/public-newsletter-form";
export const metadata = { robots: { index: false, follow: false }, referrer: "no-referrer" as const };
export default async function UnsubscribePage({searchParams}: {searchParams: Promise<{token?: string}>}) {
  const {token} = await searchParams;
  return <main className="mx-auto max-w-xl px-5 py-16"><h1 className="font-serif text-3xl">Email preferences</h1><p className="mt-4">Stop promotional updates from Artisan Lane. Your order and account messages are unaffected.</p>{token ? <PublicNewsletterForm token={token} /> : <p className="mt-6">Please use your personal unsubscribe link.</p>}</main>;
}
