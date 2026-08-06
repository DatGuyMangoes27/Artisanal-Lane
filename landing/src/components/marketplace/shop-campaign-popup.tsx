"use client";

import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Clock3, Sparkles, Store, Tag, X } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";

import type { CampaignOffer } from "@/lib/marketplace/campaign-offers";

const dismissedStorageKey = "artisan-lane:shop-campaign-popup-dismissed";
const fallbackImages = [
  "/campaigns/stitch-and-save/crochet-frog.jpg",
  "/campaigns/stitch-and-save/purple-pouch.jpg",
  "/campaigns/stitch-and-save/baby-knitwear.png",
];

function discountLabel(offer: CampaignOffer) {
  return offer.discountType === "percentage"
    ? `${offer.discountValue}% off`
    : `R${offer.discountValue.toFixed(0)} off`;
}

export function ShopCampaignPopup({ offers }: { offers: CampaignOffer[] }) {
  const [open, setOpen] = useState(false);
  const [nowMs] = useState(() => Date.now());
  const titleId = useId();
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (offers.length === 0) return;
    try {
      if (window.sessionStorage.getItem(dismissedStorageKey) === "true") return;
    } catch {
      // The campaign can still display when storage is unavailable.
    }

    const timer = window.setTimeout(() => setOpen(true), 900);
    return () => window.clearTimeout(timer);
  }, [offers.length]);

  useEffect(() => {
    if (!open) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeRef.current?.focus();

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        try {
          window.sessionStorage.setItem(dismissedStorageKey, "true");
        } catch {
          // Closing the campaign must not depend on storage access.
        }
        setOpen(false);
      }
    }

    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  function dismiss() {
    try {
      window.sessionStorage.setItem(dismissedStorageKey, "true");
    } catch {
      // Closing the campaign must not depend on storage access.
    }
    setOpen(false);
  }

  if (!open || offers.length === 0) return null;

  const activeOffers = offers.filter((offer) => {
    const startsAtMs = offer.startsAt ? Date.parse(offer.startsAt) : Number.NEGATIVE_INFINITY;
    return !Number.isFinite(startsAtMs) || startsAtMs <= nowMs;
  });
  const upcomingCount = offers.length - activeOffers.length;
  const collageOffers = [offers[0], offers[Math.floor(offers.length / 2)], offers[offers.length - 1]]
    .filter((offer): offer is CampaignOffer => Boolean(offer))
    .filter((offer, index, items) => items.findIndex((item) => item.couponId === offer.couponId) === index);
  const collageImages = collageOffers
    .map((offer) => ({
      src: offer.productImageUrl ?? offer.shopCoverImageUrl,
      alt: offer.productTitle ? `${offer.productTitle} by ${offer.shopName}` : `Work by ${offer.shopName}`,
    }))
    .filter((image): image is { src: string; alt: string } => Boolean(image.src))
    .slice(0, 3);

  while (collageImages.length < 3) {
    const index = collageImages.length;
    collageImages.push({
      src: fallbackImages[index],
      alt: "Handmade crochet and knitwork featured in Stitch and Save",
    });
  }

  return (
    <div
      className="fixed inset-0 z-[115] flex items-center justify-center bg-[#241008]/70 p-3 backdrop-blur-sm sm:p-6"
      onMouseDown={(event) => {
        if (event.currentTarget === event.target) dismiss();
      }}
    >
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="relative max-h-[calc(100dvh-1.5rem)] w-full max-w-3xl overflow-y-auto rounded-[1.75rem] border border-white/25 bg-[#FFF9F1] shadow-[0_32px_90px_rgba(42,17,8,0.45)] sm:max-h-[calc(100dvh-3rem)] sm:rounded-[2.25rem]"
      >
        <button
          ref={closeRef}
          type="button"
          onClick={dismiss}
          aria-label="Close Stitch and Save campaign"
          className="absolute right-3 top-3 z-30 flex size-10 items-center justify-center rounded-full border border-white/60 bg-white/95 text-[#4A0000] shadow-md transition hover:scale-105 hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7A0000] sm:right-5 sm:top-5"
        >
          <X className="size-5" />
        </button>

        <div className="grid md:grid-cols-[0.82fr_1.18fr]">
          <div className="relative min-h-64 overflow-hidden rounded-t-[1.75rem] bg-[#7A0000] md:min-h-full md:rounded-l-[2.25rem] md:rounded-tr-none">
            <div className="grid h-full min-h-64 grid-cols-2 grid-rows-2 gap-1">
              {collageImages.map((image, index) => (
                <div key={`${image.src}-${index}`} className={`relative ${index === 0 ? "row-span-2" : ""}`}>
                  <Image src={image.src} alt={image.alt} fill sizes="(min-width: 768px) 24vw, 50vw" className="object-cover" />
                </div>
              ))}
            </div>
            <div className="absolute inset-0 bg-gradient-to-t from-[#2B0E08]/80 via-transparent to-[#2B0E08]/15" />
            <div className="absolute bottom-5 left-5 right-5 flex h-16 items-center justify-center rounded-2xl border border-white/40 bg-[#FFF9F1]/94 px-4 shadow-lg backdrop-blur-md">
              <Image
                src="/campaigns/stitch-and-save/stitch-and-save-logo.png"
                alt="Stitch and Save"
                fill
                sizes="240px"
                className="object-cover"
              />
            </div>
          </div>

          <div className="px-5 py-7 sm:px-8 sm:py-9">
            <p className="flex items-center gap-2 text-xs font-black uppercase tracking-[0.18em] text-[#8B4513]">
              <Sparkles className="size-4 text-[#7A0000]" />
              Limited-time campaign
            </p>
            <h2 id={titleId} className="mt-2 font-serif text-4xl font-bold leading-tight text-[#4A1F0E]">
              Stitch &amp; Save is here
            </h2>
            <p className="mt-3 leading-relaxed text-[#6B5040]">
              Discover special offers from {offers.length} South African crochet and knit artisans. Shop handmade,
              support local, and use each artisan&apos;s code at checkout.
            </p>

            <div className="mt-5 grid grid-cols-2 gap-3">
              <div className="rounded-2xl bg-[#F7E4CC] p-3">
                <p className="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wide text-[#8B4513]">
                  <Tag className="size-3.5" /> Live now
                </p>
                <p className="mt-1 text-2xl font-black text-[#7A0000]">{activeOffers.length}</p>
              </div>
              <div className="rounded-2xl bg-[#FFF3CF] p-3">
                <p className="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wide text-[#8B4513]">
                  <Clock3 className="size-3.5" /> Starting soon
                </p>
                <p className="mt-1 text-2xl font-black text-[#7A0000]">{upcomingCount}</p>
              </div>
            </div>

            <div className="mt-5 grid max-h-44 gap-2 overflow-y-auto pr-1 sm:grid-cols-2">
              {offers.map((offer) => (
                <Link
                  key={offer.couponId}
                  href={`/shops/${offer.shopSlug}`}
                  onClick={dismiss}
                  className="group flex items-center justify-between gap-2 rounded-xl border border-[#EDD5BE] bg-white px-3 py-2.5 text-sm shadow-sm transition hover:-translate-y-0.5 hover:border-[#C68B62] hover:shadow-md"
                >
                  <span className="min-w-0 text-xs font-bold leading-tight text-[#4A1F0E]">{offer.shopName}</span>
                  <span className="shrink-0 text-xs font-black text-[#7A0000]">{discountLabel(offer)}</span>
                </Link>
              ))}
            </div>

            <a
              href="#all-products"
              onClick={dismiss}
              className="mt-6 flex h-12 w-full items-center justify-center gap-2 rounded-full bg-[#7A0000] px-6 font-bold text-white shadow-lg shadow-[#7A0000]/20 transition hover:-translate-y-0.5 hover:bg-[#4A0000] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7A0000] focus-visible:ring-offset-2"
            >
              <Store className="size-5" />
              Browse the marketplace
              <ArrowRight className="size-4" />
            </a>
          </div>
        </div>
      </section>
    </div>
  );
}
