import type { Metadata } from "next";
import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export const metadata: Metadata = {
  title: "Community Guidelines — Artisan Lane",
  description:
    "What is and isn't allowed on Artisan Lane, how to report content or block people, and how our team responds.",
};

export default function CommunityGuidelinesPage() {
  return (
    <main className="min-h-screen">
      <MarketplaceHeader />

      <section className="py-20">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 prose-artisan">
          <h1 className="text-4xl md:text-5xl font-bold mb-2 text-[#3A1F10]">Community Guidelines</h1>
          <p className="text-muted-foreground mb-12">Last updated: October 2026</p>

          <h2>Zero tolerance</h2>
          <p>
            Artisan Lane has no tolerance for objectionable content or abusive users. These
            guidelines apply to everything you post or send on the Artisan Lane app and website:
            shop names and bios, posts, stories, polls, comments, reviews, chat messages and your
            profile name. By using Artisan Lane you agree to follow them, and the app asks you to
            confirm them before you first post, comment, review or message. They form part of
            our{" "}
            <Link href="/terms" className="text-[#7A0000] hover:underline">
              Terms of Service
            </Link>
            .
          </p>

          <h2>1. Respect everyone</h2>
          <p>
            No hate speech, slurs, or content that attacks or demeans people because of race,
            ethnicity, nationality, religion, gender, sexual orientation, disability or any other
            part of who they are.
          </p>

          <h2>2. No harassment or threats</h2>
          <p>
            Do not bully, intimidate, threaten, stalk or repeatedly contact someone who has not
            asked to hear from you. Do not share anyone&apos;s personal information without their
            permission.
          </p>

          <h2>3. No sexual or explicit content</h2>
          <p>
            Nudity, pornography, sexually explicit language and sexual content involving minors are
            not allowed anywhere on Artisan Lane. Content that sexualises minors is reported to the
            authorities.
          </p>

          <h2>4. No scams or spam</h2>
          <p>
            No fake listings, misleading claims, phishing links, requests to pay outside Artisan
            Lane, or repetitive promotional messages. Keep orders and payments on the Platform so
            escrow can protect you.
          </p>

          <h2>5. Respect intellectual property</h2>
          <p>
            Only post photos, designs and words you made or have permission to use. Copying another
            maker&apos;s work or listing counterfeit goods is not allowed.
          </p>

          <h2>6. Honest reviews</h2>
          <p>
            Reviews should describe your genuine experience with an order. Do not post fake, paid
            or retaliatory reviews, or use a review to harass a maker or buyer.
          </p>

          <h2>How we keep Artisan Lane safe</h2>
          <ul>
            <li>
              <strong>Filtering:</strong> text containing slurs, explicit or severely abusive
              language is blocked before it is posted.
            </li>
            <li>
              <strong>Reporting:</strong> in the app, use the Report option on any post, story,
              comment, review or maker, or long-press a chat message. Reports are private.
            </li>
            <li>
              <strong>Blocking:</strong> block anyone from their profile, review or conversation.
              They can no longer comment on your posts or message you, and you no longer see their
              content.
            </li>
            <li>
              <strong>Response:</strong> our team reviews reports within 24 hours. We remove
              content that breaks these guidelines and suspend or permanently remove the accounts
              of people who post it.
            </li>
          </ul>

          <h2>Contact us</h2>
          <p>
            To report a problem or ask about these guidelines, email{" "}
            <a href="mailto:nicky@artisanlanesa.com" className="text-[#7A0000] hover:underline">
              nicky@artisanlanesa.com
            </a>{" "}
            or WhatsApp{" "}
            <a href="https://wa.me/27730687908" className="text-[#7A0000] hover:underline">
              +27 73 068 7908
            </a>
            .
          </p>
        </div>
      </section>
    </main>
  );
}
