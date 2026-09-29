import Link from "next/link";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export const metadata = { title: "Photo guide — Artisan Lane" };

export default function PhotoGuide() {
  return <div className="min-h-screen bg-background"><MarketplaceHeader />
    <main className="mx-auto max-w-3xl px-5 py-12">
      <p className="text-xs font-bold uppercase tracking-widest text-artisan-terracotta">Artisan help</p>
      <h1 className="mt-3 font-serif text-4xl">Photos that show your craft clearly</h1>
      <p className="mt-5 leading-7">Use sharp, well-lit photographs with natural colours. Recommended dimensions below are preparation guidance, not mandatory sizes.</p>
      <section className="mt-8 space-y-4 rounded-3xl border border-artisan-clay p-6">
        <h2 className="font-serif text-2xl">Product photographs</h2>
        <p>The website editor crops product photographs to a square and saves them at 1200 × 1200 pixels. Start with an original at least this size and leave space around the product.</p>
        <p>You can choose up to eight product photos. The first is the main listing image. Product uploads are limited to 8 MB per processed image; the editor saves the crop as a JPG.</p>
      </section>
      <section className="mt-6 space-y-4 rounded-3xl border border-artisan-clay p-6">
        <h2 className="font-serif text-2xl">Shop cover / banner</h2>
        <p>Use a high-resolution landscape photograph. Around 1920 pixels wide is a useful starting point, not a required size. Avoid placing text, logos or important product details near the edges.</p>
        <p>The banner fills different shapes on desktop and mobile, so some cropping is unavoidable. Keep the subject near the centre and check your public shop on both screen sizes after saving.</p>
      </section>
      <section className="mt-6 space-y-4 rounded-3xl border border-artisan-clay p-6">
        <h2 className="font-serif text-2xl">Shop logo and formats</h2>
        <p>A square logo around 800 × 800 pixels is recommended. Leave a little clear space around it. JPG is a good choice for photographs; PNG is useful for logos.</p>
        <p>Aim for files under 2 MB where possible for faster uploads. This is a performance recommendation, not a universal upload limit; product limits are listed above.</p>
      </section>
      <nav className="mt-8 flex flex-wrap gap-6 text-sm font-semibold underline"><Link href="/vendor/profile/shop">Shop settings</Link><Link href="/vendor/products">Your products</Link><Link href="/terms#artisans">Artisan terms</Link></nav>
    </main>
  </div>;
}
