"use client";

import Image from "next/image";
import Link from "next/link";
import {
  Check,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Copy,
  MapPin,
  Sparkles,
  Store,
  X,
} from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";

import type { CampaignOffer } from "@/lib/marketplace/campaign-offers";

const dismissedStorageKey = "artisan-lane:campaign-popup-dismissed";
const campaignImages = [
  "/campaigns/stitch-and-save/crochet-frog.jpg",
  "/campaigns/stitch-and-save/purple-pouch.jpg",
  "/campaigns/stitch-and-save/baby-knitwear.png",
];

function money(value: number) {
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
    maximumFractionDigits: 0,
  }).format(value);
}

function discountLabel(offer: CampaignOffer) {
  return offer.discountType === "percentage"
    ? `${offer.discountValue}% off`
    : `${money(offer.discountValue)} off`;
}

function endingLabel(endsAt: string | null) {
  if (!endsAt) return null;
  return `Ends ${new Intl.DateTimeFormat("en-ZA", {
    day: "numeric",
    month: "short",
  }).format(new Date(endsAt))}`;
}

function startingLabel(startsAt: string) {
  return new Intl.DateTimeFormat("en-ZA", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Africa/Johannesburg",
  }).format(new Date(startsAt));
}

function countdownParts(startsAtMs: number, nowMs: number) {
  const totalSeconds = Math.max(0, Math.floor((startsAtMs - nowMs) / 1000));
  const days = Math.floor(totalSeconds / 86_400);
  const hours = Math.floor((totalSeconds % 86_400) / 3_600);
  const minutes = Math.floor((totalSeconds % 3_600) / 60);
  const seconds = totalSeconds % 60;

  return [
    { label: "Days", value: days },
    { label: "Hours", value: hours },
    { label: "Mins", value: minutes },
    { label: "Secs", value: seconds },
  ];
}

export function HomepageCampaignPopup({ offers }: { offers: CampaignOffer[] }) {
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const [copiedCode, setCopiedCode] = useState<string | null>(null);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const titleId = useId();
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (offers.length === 0) return;

    try {
      if (window.sessionStorage.getItem(dismissedStorageKey) === "true") return;
    } catch {
      // The campaign can still display when storage is unavailable.
    }

    const timer = window.setTimeout(() => setOpen(true), 650);
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
      if (event.key === "ArrowLeft") {
        setActiveIndex((current) => (current - 1 + offers.length) % offers.length);
        setCopiedCode(null);
      }
      if (event.key === "ArrowRight") {
        setActiveIndex((current) => (current + 1) % offers.length);
        setCopiedCode(null);
      }
    }

    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [offers.length, open]);

  useEffect(() => {
    if (!open || offers.length < 2) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const timer = window.setInterval(() => {
      setActiveIndex((current) => (current + 1) % offers.length);
      setCopiedCode(null);
    }, 5500);
    return () => window.clearInterval(timer);
  }, [offers.length, open]);

  useEffect(() => {
    if (!open) return;
    setNowMs(Date.now());
    const timer = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [open]);

  if (!open || offers.length === 0) return null;

  const offer = offers[activeIndex] ?? offers[0];
  const ends = endingLabel(offer.endsAt);
  const campaignImage = campaignImages[activeIndex % campaignImages.length];
  const startsAtMs = offer.startsAt ? Date.parse(offer.startsAt) : Number.NaN;
  const isUpcoming = Number.isFinite(startsAtMs) && startsAtMs > nowMs;
  const countdown = isUpcoming ? countdownParts(startsAtMs, nowMs) : [];

  function dismiss() {
    try {
      window.sessionStorage.setItem(dismissedStorageKey, "true");
    } catch {
      // Closing the campaign must not depend on storage access.
    }
    setOpen(false);
  }

  function showPrevious() {
    setActiveIndex((current) => (current - 1 + offers.length) % offers.length);
    setCopiedCode(null);
  }

  function showNext() {
    setActiveIndex((current) => (current + 1) % offers.length);
    setCopiedCode(null);
  }

  async function copyCode() {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(offer.code);
      } else {
        const input = document.createElement("textarea");
        input.value = offer.code;
        input.setAttribute("readonly", "");
        input.style.position = "fixed";
        input.style.opacity = "0";
        document.body.appendChild(input);
        input.select();
        const copied = document.execCommand("copy");
        input.remove();
        if (!copied) throw new Error("Copy command was rejected");
      }
      setCopiedCode(offer.code);
    } catch {
      const input = document.createElement("textarea");
      input.value = offer.code;
      input.setAttribute("readonly", "");
      input.style.position = "fixed";
      input.style.opacity = "0";
      document.body.appendChild(input);
      input.select();
      const copied = document.execCommand("copy");
      input.remove();
      setCopiedCode(copied ? offer.code : null);
    }
  }

  return (
    <div
      className="fixed inset-0 z-[120] flex items-center justify-center bg-[#241008]/70 p-3 backdrop-blur-sm sm:p-6"
      onMouseDown={(event) => {
        if (event.currentTarget === event.target) dismiss();
      }}
    >
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="relative max-h-[calc(100dvh-1.5rem)] w-full max-w-4xl overflow-y-auto rounded-[1.75rem] border border-white/20 bg-[#FFF9F1] shadow-[0_32px_90px_rgba(42,17,8,0.45)] sm:max-h-[calc(100dvh-3rem)] sm:rounded-[2.25rem]"
      >
        <button
          ref={closeRef}
          type="button"
          onClick={dismiss}
          aria-label="Close campaign offers"
          className="absolute right-3 top-3 z-30 flex size-10 items-center justify-center rounded-full border border-white/60 bg-white/90 text-[#4A0000] shadow-md transition hover:scale-105 hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7A0000] sm:right-5 sm:top-5"
        >
          <X className="size-5" />
        </button>

        <div className="grid min-h-[31rem] md:grid-cols-[0.9fr_1.1fr]">
          <div className="relative min-h-56 overflow-hidden rounded-t-[1.75rem] bg-gradient-to-br from-[#7A0000] via-[#A33A18] to-[#D4A020] md:min-h-full md:rounded-l-[2.25rem] md:rounded-tr-none">
            <Image
              key={campaignImage}
              src={campaignImage}
              alt="Handmade crochet and knitwork featured in the Stitch and Save campaign"
              fill
              sizes="(min-width: 768px) 40vw, 100vw"
              className="object-cover"
              priority
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[#2B0E08]/90 via-[#47150B]/35 to-transparent" />
            <div className="absolute left-5 top-5 flex h-16 w-48 items-center justify-center rounded-2xl border border-white/40 bg-[#FFF9F1]/92 px-3 shadow-lg backdrop-blur-md sm:left-7 sm:top-7 sm:h-20 sm:w-56">
              <Image
                src="/campaigns/stitch-and-save/stitch-and-save-logo.png"
                alt="Stitch and Save"
                fill
                sizes="224px"
                className="object-cover"
              />
            </div>
            <div className="absolute inset-x-0 bottom-0 p-5 text-white sm:p-7">
              <div className="mb-4 flex items-center gap-3">
                <div className="relative flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-2xl border-2 border-white/80 bg-[#FFF9F1] text-xl font-bold text-[#7A0000] shadow-xl">
                  {offer.shopLogoUrl ? (
                    <Image
                      src={offer.shopLogoUrl}
                      alt={`${offer.shopName} logo`}
                      fill
                      sizes="56px"
                      className="object-cover"
                    />
                  ) : (
                    offer.shopName.charAt(0).toUpperCase()
                  )}
                </div>
                <div className="min-w-0">
                  <p className="text-xs font-semibold uppercase tracking-[0.15em] text-[#FFD874]">
                    Featured artisan
                  </p>
                  <h2 id={titleId} className="line-clamp-2 text-2xl font-bold leading-tight sm:text-3xl">
                    {offer.shopName}
                  </h2>
                </div>
              </div>
              {offer.shopLocation ? (
                <p className="flex items-center gap-1.5 text-sm text-white/85">
                  <MapPin className="size-4" />
                  {offer.shopLocation}
                </p>
              ) : null}
            </div>
          </div>

          <div className="relative flex flex-col justify-center px-5 py-7 sm:px-9 sm:py-10 lg:px-12">
            <div className="pointer-events-none absolute right-0 top-0 size-56 rounded-full bg-[#D4A020]/10 blur-3xl" />
            <p className="relative mb-2 flex items-center gap-2 text-sm font-bold uppercase tracking-[0.18em] text-[#8B4513]">
              <Sparkles className="size-4 text-[#7A0000]" />
              Stitch &amp; Save
            </p>
            <p className="relative text-4xl font-black leading-none text-[#7A0000] sm:text-5xl">
              {discountLabel(offer)}
            </p>
            <p className="relative mt-3 text-base leading-relaxed text-[#6B5040] sm:text-lg">
              {offer.description ||
                (offer.scope === "products"
                  ? "Save on selected handmade pieces from this artisan."
                  : "Save across this artisan's beautiful handmade collection.")}
            </p>

            {isUpcoming && offer.startsAt ? (
              <div className="relative mt-5 rounded-2xl border border-[#D4A020]/45 bg-gradient-to-br from-[#FFF3CF] to-[#F7E4CC] p-4 shadow-sm">
                <div className="mb-3 flex items-center justify-between gap-3">
                  <p className="flex items-center gap-2 text-sm font-black uppercase tracking-[0.14em] text-[#7A0000]">
                    <Clock3 className="size-4" />
                    Offer starts in
                  </p>
                  <p className="text-xs font-bold text-[#8B4513]">{startingLabel(offer.startsAt)}</p>
                </div>
                <div className="grid grid-cols-4 gap-2" aria-label={`Countdown to ${offer.shopName} offer`}>
                  {countdown.map((part) => (
                    <div key={part.label} className="rounded-xl bg-white/85 px-1 py-2 text-center shadow-sm">
                      <p className="text-xl font-black tabular-nums text-[#7A0000] sm:text-2xl">
                        {String(part.value).padStart(2, "0")}
                      </p>
                      <p className="text-[10px] font-bold uppercase tracking-wide text-[#8B6A54]">
                        {part.label}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}

            <div className="relative mt-5 rounded-2xl border border-dashed border-[#C68B62] bg-[#F7E4CC]/65 p-4">
              <p className="mb-2 text-xs font-bold uppercase tracking-[0.16em] text-[#8B4513]">
                {isUpcoming ? "Save this discount code" : "Use discount code"}
              </p>
              <div className="flex items-center justify-between gap-3">
                <code className="truncate text-2xl font-black tracking-[0.12em] text-[#3A1F10]">
                  {offer.code}
                </code>
                <button
                  type="button"
                  onClick={copyCode}
                  className="flex shrink-0 items-center gap-1.5 rounded-full bg-white px-3 py-2 text-xs font-bold text-[#7A0000] shadow-sm transition hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7A0000]"
                >
                  {copiedCode === offer.code ? (
                    <><Check className="size-4" /> Copied</>
                  ) : (
                    <><Copy className="size-4" /> Copy</>
                  )}
                </button>
              </div>
              <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs font-medium text-[#6B5040]">
                <span>{offer.scope === "products" ? "Selected products" : "Whole shop"}</span>
                {isUpcoming ? <span>Available when countdown ends</span> : null}
                {offer.minimumSubtotal > 0 ? <span>Minimum {money(offer.minimumSubtotal)}</span> : null}
                {ends ? <span>{ends}</span> : null}
              </div>
            </div>

            <Link
              href={`/shops/${offer.shopSlug}`}
              onClick={dismiss}
              className="relative mt-6 flex h-13 w-full items-center justify-center gap-2 rounded-full bg-[#7A0000] px-6 font-bold text-white shadow-lg shadow-[#7A0000]/20 transition hover:-translate-y-0.5 hover:bg-[#4A0000] hover:shadow-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7A0000] focus-visible:ring-offset-2"
            >
              <Store className="size-5" />
              Shop this offer
            </Link>

            {offers.length > 1 ? (
              <div className="relative mt-6 flex items-center justify-between gap-4">
                <button
                  type="button"
                  onClick={showPrevious}
                  aria-label="Previous campaign shop"
                  className="flex size-10 items-center justify-center rounded-full border border-[#EDD5BE] bg-white text-[#7A0000] transition hover:bg-[#F7E4CC] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7A0000]"
                >
                  <ChevronLeft className="size-5" />
                </button>
                <div className="flex items-center gap-2" aria-label={`${activeIndex + 1} of ${offers.length}`}>
                  {offers.map((item, index) => (
                    <button
                      key={item.shopId}
                      type="button"
                      onClick={() => {
                        setActiveIndex(index);
                        setCopiedCode(null);
                      }}
                      aria-label={`Show offer from ${item.shopName}`}
                      aria-current={index === activeIndex ? "true" : undefined}
                      className={`h-2.5 rounded-full transition-all ${
                        index === activeIndex ? "w-8 bg-[#7A0000]" : "w-2.5 bg-[#DFC4AD] hover:bg-[#C68B62]"
                      }`}
                    />
                  ))}
                </div>
                <button
                  type="button"
                  onClick={showNext}
                  aria-label="Next campaign shop"
                  className="flex size-10 items-center justify-center rounded-full border border-[#EDD5BE] bg-white text-[#7A0000] transition hover:bg-[#F7E4CC] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7A0000]"
                >
                  <ChevronRight className="size-5" />
                </button>
              </div>
            ) : null}
          </div>
        </div>
      </section>
    </div>
  );
}
