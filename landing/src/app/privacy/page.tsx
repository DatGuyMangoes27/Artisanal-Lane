import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Privacy Policy — Artisan Lane",
  description: "Learn how Artisan Lane collects, uses, and protects your personal information.",
};

export default function PrivacyPage() {
  return (
    <main className="min-h-screen">
      <nav className="glass sticky top-0 z-50 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Link href="/" className="flex items-center gap-2">
              <Image src="/logo.png" alt="Artisan Lane" width={36} height={36} className="rounded-lg" />
              <span className="text-xl font-bold text-[#3A1F10]">Artisan Lane</span>
            </Link>
            <Link href="/" className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors flex items-center gap-1">
              <ArrowLeft className="w-4 h-4" /> Back
            </Link>
          </div>
        </div>
      </nav>

      <section className="py-20">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 prose-artisan">
          <h1 className="text-4xl md:text-5xl font-bold mb-2 text-[#3A1F10]">Privacy Policy</h1>
          <p className="text-muted-foreground mb-12">Last updated: March 2026</p>

          <h2>1. Introduction</h2>
          <p>
            Artisan Lane (&quot;we&quot;, &quot;us&quot;, or &quot;our&quot;) is committed to protecting the privacy of everyone
            who uses our mobile application and website. This Privacy Policy explains how we collect,
            use, disclose, and safeguard your personal information in compliance with the Protection
            of Personal Information Act (POPIA) of South Africa.
          </p>

          <h2>2. Information We Collect</h2>
          <h3>Account Information</h3>
          <p>
            When you create an account, we collect your name, email address, and the account type
            you select (buyer or artisan). Artisan applicants also provide a business name, location,
            delivery capabilities, and turnaround time information.
          </p>
          <h3>Transaction Data</h3>
          <p>
            When you make a purchase, we collect delivery addresses, order details, and payment
            references. We do not store full credit card numbers — all payment processing is handled
            securely by our escrow partner, TradeSafe.
          </p>
          <h3>Usage Data</h3>
          <p>
            We automatically collect device information, app usage patterns, search queries, and
            interaction data to improve our service. This data is anonymised wherever possible.
          </p>

          <h2>3. How We Use Your Information</h2>
          <ul>
            <li>To create and manage your account</li>
            <li>To process orders, deliveries, and escrow payments</li>
            <li>To communicate with you about orders, updates, and promotions</li>
            <li>To review artisan applications and maintain marketplace quality</li>
            <li>To improve our app, troubleshoot issues, and develop new features</li>
            <li>To comply with legal obligations</li>
          </ul>

          <h2>4. Information Sharing</h2>
          <p>We may share your information with:</p>
          <ul>
            <li><strong>Artisans / Buyers:</strong> Order-related details necessary to fulfil and deliver purchases (e.g. delivery address shared with the artisan).</li>
            <li><strong>Payment Providers:</strong> TradeSafe for escrow payment processing.</li>
            <li><strong>Delivery Partners:</strong> Courier Guy and Pargo for shipping and logistics.</li>
            <li><strong>Legal Requirements:</strong> When required by South African law or to protect our legal rights.</li>
          </ul>
          <p>We never sell your personal information to third parties.</p>

          <h2>5. Data Security</h2>
          <p>
            We use industry-standard security measures to protect your data, including encryption
            in transit (TLS/SSL), secure database hosting via Supabase, and access controls.
            However, no method of electronic storage is 100% secure, and we cannot guarantee
            absolute security.
          </p>

          <h2>6. Your Rights Under POPIA</h2>
          <p>As a South African resident, you have the right to:</p>
          <ul>
            <li>Access the personal information we hold about you</li>
            <li>Request correction of inaccurate information</li>
            <li>Request deletion of your personal information</li>
            <li>Object to the processing of your information</li>
            <li>Lodge a complaint with the Information Regulator</li>
          </ul>
          <p>
            To exercise any of these rights, please contact us at{" "}
            <a href="mailto:privacy@artisanlane.co.za" className="text-[#7A0000] hover:underline">
              privacy@artisanlane.co.za
            </a>.
          </p>

          <h2>7. Data Retention</h2>
          <p>
            We retain your personal information for as long as your account is active or as needed
            to provide our services. Transaction records are retained for a minimum of 5 years
            as required by South African tax and commercial law.
          </p>

          <h2>8. Cookies & Tracking</h2>
          <p>
            Our website uses essential cookies to ensure functionality. We do not use third-party
            advertising cookies. Analytics data is collected anonymously to improve the user experience.
          </p>

          <h2>9. Children&apos;s Privacy</h2>
          <p>
            Artisan Lane is not intended for use by children under 18. We do not knowingly collect
            personal information from minors.
          </p>

          <h2>10. Changes to This Policy</h2>
          <p>
            We may update this Privacy Policy from time to time. We will notify you of any material
            changes by posting the updated policy on our website and app with a revised &quot;Last
            updated&quot; date.
          </p>

          <h2>11. Contact Us</h2>
          <p>
            If you have any questions about this Privacy Policy, please contact us at:{" "}
            <a href="mailto:privacy@artisanlane.co.za" className="text-[#7A0000] hover:underline">
              privacy@artisanlane.co.za
            </a>
          </p>
        </div>
      </section>
    </main>
  );
}
