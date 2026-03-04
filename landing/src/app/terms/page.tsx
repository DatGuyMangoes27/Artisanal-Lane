import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Terms of Service — Artisan Lane",
  description: "Read the terms and conditions governing the use of the Artisan Lane marketplace.",
};

export default function TermsPage() {
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
          <h1 className="text-4xl md:text-5xl font-bold mb-2 text-[#3A1F10]">Terms of Service</h1>
          <p className="text-muted-foreground mb-12">Last updated: March 2026</p>

          <h2>1. Acceptance of Terms</h2>
          <p>
            By accessing or using the Artisan Lane mobile application or website (&quot;Platform&quot;),
            you agree to be bound by these Terms of Service. If you do not agree, please do not
            use the Platform.
          </p>

          <h2>2. About Artisan Lane</h2>
          <p>
            Artisan Lane is a curated marketplace that connects South African artisans with buyers.
            We provide the platform, payment escrow, and support infrastructure. We do not manufacture,
            stock, or ship any products — artisans are independent sellers responsible for their
            own products and fulfilment.
          </p>

          <h2>3. Account Registration</h2>
          <p>
            You must create an account to make purchases or sell on the Platform. You are responsible
            for maintaining the confidentiality of your login credentials and for all activity under
            your account. You must provide accurate, current information and update it as needed.
          </p>

          <h2>4. Buyers</h2>
          <h3>4.1 Orders &amp; Payments</h3>
          <p>
            All payments are processed through TradeSafe&apos;s escrow system. When you place an order,
            your funds are held securely until you confirm receipt of your order. If you do not
            confirm or raise a dispute within 14 days of delivery, funds are automatically released
            to the artisan.
          </p>
          <h3>4.2 Shipping</h3>
          <p>
            Shipping options and costs are set by each artisan. Available methods may include
            Courier Guy (door-to-door and locker-to-locker), Pargo pickup points, PAXI at PEP stores,
            and Market Pickup (in-person collection). Delivery times are estimates and may vary.
          </p>
          <h3>4.3 Returns &amp; Disputes</h3>
          <p>
            If you receive an item that is significantly not as described, damaged, or defective,
            you may raise a dispute before funds are released. We will mediate between the buyer
            and artisan to reach a fair resolution. Customised or made-to-order items may not be
            eligible for returns unless faulty.
          </p>
          <h3>4.4 Cart Expiry</h3>
          <p>
            Items added to your cart are reserved for 48 hours. After this period, they may be
            automatically removed to ensure availability for other buyers.
          </p>

          <h2>5. Artisans (Sellers)</h2>
          <h3>5.1 Application &amp; Approval</h3>
          <p>
            Anyone may apply to sell on Artisan Lane. Applications are reviewed by our team to
            ensure quality standards are met. Approval is at our sole discretion. We may request
            additional information or decline an application.
          </p>
          <h3>5.2 Product Listings</h3>
          <p>
            Artisans are responsible for the accuracy of their listings, including descriptions,
            photos, pricing, stock levels, and care instructions. All products must be handmade,
            hand-assembled, or artisan-produced. Mass-produced items are not permitted.
          </p>
          <h3>5.3 Fulfilment</h3>
          <p>
            Artisans must fulfil orders within the turnaround time stated in their shop settings.
            If an artisan is unable to fulfil orders temporarily, they should enable Out of Office
            mode with an expected return date.
          </p>
          <h3>5.4 Commission</h3>
          <p>
            Artisan Lane charges a commission on each sale. The current commission rate is communicated
            during the application process and in your vendor dashboard. We reserve the right to
            adjust commission rates with 30 days&apos; notice.
          </p>
          <h3>5.5 Payouts</h3>
          <p>
            Funds are released from escrow once the buyer confirms receipt. Payouts are processed
            to your registered bank account according to our payout schedule.
          </p>

          <h2>6. Prohibited Conduct</h2>
          <p>You may not:</p>
          <ul>
            <li>Use the Platform for any illegal purpose</li>
            <li>List mass-produced, counterfeit, or prohibited items</li>
            <li>Manipulate reviews, ratings, or search results</li>
            <li>Circumvent the escrow payment system</li>
            <li>Harass, abuse, or threaten other users</li>
            <li>Attempt to gain unauthorised access to any part of the Platform</li>
          </ul>

          <h2>7. Intellectual Property</h2>
          <p>
            The Artisan Lane name, logo, branding, and app design are our intellectual property.
            Artisans retain ownership of their product images and descriptions but grant us a
            licence to display them on the Platform for the purpose of facilitating sales.
          </p>

          <h2>8. Limitation of Liability</h2>
          <p>
            Artisan Lane acts as a marketplace facilitator. We are not responsible for the quality,
            safety, or legality of items listed by artisans, the accuracy of listings, or the
            ability of artisans to complete sales. Our liability is limited to the extent permitted
            by South African law.
          </p>

          <h2>9. Termination</h2>
          <p>
            We may suspend or terminate your account at any time for violation of these Terms or
            for any conduct that we believe is harmful to the Platform or other users. You may
            delete your account at any time by contacting us.
          </p>

          <h2>10. Governing Law</h2>
          <p>
            These Terms are governed by the laws of the Republic of South Africa. Any disputes
            will be subject to the jurisdiction of the South African courts.
          </p>

          <h2>11. Changes to These Terms</h2>
          <p>
            We may update these Terms from time to time. We will notify you of material changes
            via the app or email. Continued use of the Platform after changes constitutes acceptance
            of the updated Terms.
          </p>

          <h2>12. Contact</h2>
          <p>
            For questions about these Terms, please contact us at{" "}
            <a href="mailto:legal@artisanlane.co.za" className="text-[#7A0000] hover:underline">
              legal@artisanlane.co.za
            </a>
          </p>
        </div>
      </section>
    </main>
  );
}
