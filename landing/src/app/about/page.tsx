import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, Quote, ShoppingBag, Sparkles, Store } from "lucide-react";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export const metadata: Metadata = {
  title: "Meet the Founder — Artisan Lane",
  description:
    "Meet Nicky Hendricks, founder of Artisan Lane — a curated marketplace built to help South African artisans and small handmade businesses grow.",
};

type QA = {
  question: string;
  answer: string[];
};

const interview: QA[] = [
  {
    question: "Tell us a little bit about yourself.",
    answer: [
      "I am a Christ follower, mom to two girls, a typical Virgo and a nature lover.",
      "I have spent the last 23 years parenting and managing a couple of properties. I am a chef by trade, a creative and an ideas person — I have a host of ideas running through my mind on any given day.",
    ],
  },
  {
    question: "Where did the idea for Artisan Lane come from?",
    answer: [
      "I've always loved crafts and craft markets. I connect with handmade, natural anything and small business. As my children got older, I started considering my next chapter.",
      "I began doing research as to what was available online for handmade in South Africa. Not much — and none that don't charge a substantial commission fee.",
      "I felt an injustice here, and a desire to create something that would help small businesses with beautifully crafted handmade products grow.",
      "That's really where the idea for Artisan Lane began.",
    ],
  },
  {
    question: "What drew you to handmade products specifically?",
    answer: [
      "There is something very personal about handmade products. Every piece has a story, a person behind it with a talent and a dream. There is a level of care and time that you simply cannot replicate with mass production.",
      "I am a supporter of local, especially markets. I love walking around, chatting to creators, hearing how things are made, and where their story of turning passion into purpose began.",
      "I dabble in craft myself, so I have a huge appreciation for the time, skill and effort it takes to master one.",
    ],
  },
  {
    question: "Do you personally buy from craft markets?",
    answer: [
      "Absolutely. I'm definitely a market buyer — a bit of a weakness, really. I see what's behind the product and then really want to buy. Got to curb that, given I am now fully immersed in handmade.",
      "One of my favourite market buys is made by an artisan named Trevor, who works with old wine barrels and creates the most beautiful pieces. Mine is a lazy Susan. He and his wife mostly sell at markets, and their products are incredible.",
      "Meeting people like that is actually a big part of why Artisan Lane matters to me. There are so many talented creators making beautiful things that deserve a much bigger audience.",
    ],
  },
  {
    question: "What do you hope Artisan Lane becomes for local creators?",
    answer: [
      "I want Artisan Lane to become a space where creators feel supported and seen — where they can learn and grow their business without feeling overwhelmed by excessive fees or complicated systems.",
      "There's so much talent in South Africa, and I really believe people are looking for more meaningful, thoughtful purchases again. Artisan Lane is about creating a home for those makers and helping more people discover the value of handmade.",
    ],
  },
  {
    question: "Why the name Artisan Lane?",
    answer: [
      "I believe that when you reach the point with your craft where you are willing to put a price on it, display it proudly, and confidently sell it, you are no longer dabbling — you have become an artisan. A highly skilled craft worker, the dictionary definition.",
      "As Artisan Lane is a curated platform, I chose to honour artisans with that well-deserved name.",
    ],
  },
];

export default function AboutPage() {
  return (
    <main className="min-h-screen">
      <MarketplaceHeader activeItem="about" />

      <section className="relative overflow-hidden pattern-bg">
        <div className="bg-gradient-to-b from-[#FDF5EC] via-[#FDF5EC]/80 to-transparent">
          <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20 md:py-28 text-center">
            <span className="inline-flex items-center gap-2 rounded-full border border-[#EDD5BE] bg-white/70 px-4 py-1.5 text-sm font-medium text-[#7A0000]">
              <Sparkles className="w-4 h-4" /> Our Story
            </span>
            <h1 className="mt-6 text-4xl md:text-6xl font-bold tracking-tight text-[#3A1F10]">
              Meet <span className="gradient-text italic">Nicky Hendricks</span>
            </h1>
            <p className="mt-4 text-lg md:text-xl text-muted-foreground">
              Founder of Artisan Lane
            </p>
            <p className="mt-6 text-base md:text-lg text-muted-foreground leading-relaxed">
              A chef by trade, a creative at heart, and a lifelong supporter of local makers — Nicky
              built Artisan Lane to give South African artisans a home where their handmade craft can
              be seen, celebrated, and grow.
            </p>
          </div>
        </div>
      </section>

      <section className="pb-8">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
          {interview.map((item, index) => (
            <article key={item.question}>
              <h2 className="flex gap-3 text-2xl md:text-3xl font-bold text-[#3A1F10]">
                <span className="mt-1 h-7 w-1.5 shrink-0 rounded-full bg-gradient-to-b from-[#7A0000] to-[#D4A020]" />
                {item.question}
              </h2>
              <div className="mt-4 space-y-4 pl-[1.875rem]">
                {item.answer.map((paragraph) => (
                  <p key={paragraph} className="text-muted-foreground leading-relaxed md:text-lg">
                    {paragraph}
                  </p>
                ))}
              </div>

              {index === 2 ? (
                <figure className="my-12 rounded-2xl border border-[#EDD5BE] bg-white/60 p-8 md:p-10">
                  <Quote className="h-8 w-8 text-[#D4A020]" />
                  <blockquote className="mt-4 font-serif text-2xl md:text-3xl leading-snug text-[#3A1F10]">
                    “Every piece has a story, a person behind it with a talent and a dream.”
                  </blockquote>
                  <figcaption className="mt-4 text-sm font-medium text-[#7A0000]">
                    Nicky Hendricks
                  </figcaption>
                </figure>
              ) : null}
            </article>
          ))}
        </div>
      </section>

      <section className="py-20">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="rounded-3xl border border-[#EDD5BE] bg-gradient-to-br from-[#FDF5EC] to-white p-8 md:p-12 text-center">
            <h2 className="text-2xl md:text-3xl font-bold text-[#3A1F10]">
              Be part of the lane.
            </h2>
            <p className="mt-3 text-muted-foreground md:text-lg">
              Discover handmade pieces from South African makers, or bring your own craft to a
              community that celebrates it.
            </p>
            <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
              <Link
                href="/shop"
                className="inline-flex w-full sm:w-auto items-center justify-center gap-2 rounded-full bg-[#7A0000] px-6 py-3 font-semibold text-white transition-colors hover:bg-[#5e0000]"
              >
                <ShoppingBag className="h-5 w-5" /> Explore the marketplace
              </Link>
              <Link
                href="/artisans"
                className="inline-flex w-full sm:w-auto items-center justify-center gap-2 rounded-full border border-[#EDD5BE] bg-white px-6 py-3 font-semibold text-[#3A1F10] transition-colors hover:bg-[#FDF5EC]"
              >
                <Store className="h-5 w-5" /> Meet the artisans
                <ArrowRight className="h-4 w-4" />
              </Link>
              <Link
                href="/login?intent=vendor"
                className="inline-flex w-full sm:w-auto items-center justify-center gap-2 rounded-full border border-[#7A0000] bg-white px-6 py-3 font-semibold text-[#7A0000] transition-colors hover:bg-[#7A0000] hover:text-white"
              >
                <Sparkles className="h-5 w-5" /> Apply as a shop
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
