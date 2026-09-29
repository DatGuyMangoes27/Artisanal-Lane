import Link from "next/link";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { PublicNewsletterForm } from "@/components/marketplace/public-newsletter-form";
export default function StayUpdatedPage() {
  return <><MarketplaceHeader /><main className="mx-auto max-w-xl px-5 py-16"><p className="text-xs font-bold uppercase tracking-widest text-artisan-terracotta">A little handmade inspiration</p><h1 className="mt-4 font-serif text-4xl">Stay <span className="gradient-text italic">in the loop</span></h1><p className="mt-4 leading-7 text-muted-foreground">Fresh finds, artisan stories and special offers. Just your email—no login or account required.</p><PublicNewsletterForm /><Link href="/privacy" className="mt-6 inline-block text-sm underline">How we use your information</Link></main></>;
}
