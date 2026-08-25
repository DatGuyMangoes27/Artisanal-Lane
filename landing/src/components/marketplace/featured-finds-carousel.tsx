"use client";

import Image from "next/image";
import Link from "next/link";
import { ArrowRight, ChevronLeft, ChevronRight } from "lucide-react";
import { useEffect, useState } from "react";

import { getProductPrimaryImage } from "@/lib/marketplace/format";
import type { MarketplaceProduct } from "@/lib/marketplace/types";

export function FeaturedFindsCarousel({ products }: { products: MarketplaceProduct[] }) {
  const slides = products.slice(0, 5);
  const [activeIndex, setActiveIndex] = useState(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused || slides.length < 2) return;
    const timer = window.setInterval(() => {
      setActiveIndex((index) => (index + 1) % slides.length);
    }, 5500);
    return () => window.clearInterval(timer);
  }, [paused, slides.length]);

  if (slides.length === 0) return <div className="min-h-[560px] bg-[#D9BFA9] lg:min-h-full" />;

  const activeProduct = slides[activeIndex] ?? slides[0];
  const move = (direction: number) => {
    setActiveIndex((index) => (index + direction + slides.length) % slides.length);
  };

  return (
    <div
      className="relative min-h-[560px] overflow-hidden bg-[#D9BFA9] lg:min-h-full"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocusCapture={() => setPaused(true)}
      onBlurCapture={() => setPaused(false)}
    >
      <Link key={activeProduct.id} href={`/products/${activeProduct.id}`} className="group absolute inset-0 animate-in fade-in duration-700">
        <Image src={getProductPrimaryImage(activeProduct)} alt={activeProduct.title} fill priority sizes="(min-width: 1024px) 55vw, 100vw" className="object-cover transition duration-1000 group-hover:scale-[1.025]" />
        <div className="absolute inset-0 bg-gradient-to-t from-black/65 via-black/5 to-transparent" />
        <div className="absolute bottom-20 left-7 right-7 flex items-end justify-between gap-5 text-white sm:bottom-24 sm:left-10 sm:right-10">
          <div>
            <p className="mb-2 text-[10px] font-bold uppercase tracking-[0.22em] text-white/75">Featured find · {activeProduct.shop?.name}</p>
            <h2 className="max-w-lg font-serif text-2xl font-semibold leading-tight sm:text-3xl">{activeProduct.title}</h2>
          </div>
          <span className="hidden size-12 shrink-0 items-center justify-center rounded-full bg-white text-[#351711] transition group-hover:translate-x-1 sm:flex"><ArrowRight /></span>
        </div>
      </Link>

      {slides.length > 1 ? (
        <div className="absolute inset-x-6 bottom-5 flex items-center justify-between gap-4 sm:inset-x-10 sm:bottom-7">
          <div className="flex items-center gap-2" aria-label="Choose featured find">
            {slides.map((product, index) => (
              <button
                key={product.id}
                type="button"
                aria-label={`Show ${product.title}`}
                aria-current={index === activeIndex ? "true" : undefined}
                onClick={() => setActiveIndex(index)}
                className={`h-1.5 rounded-full transition-all ${index === activeIndex ? "w-9 bg-white" : "w-4 bg-white/45 hover:bg-white/75"}`}
              />
            ))}
          </div>
          <div className="flex gap-2">
            <button type="button" aria-label="Previous featured find" onClick={() => move(-1)} className="flex size-10 items-center justify-center rounded-full border border-white/50 bg-black/15 text-white backdrop-blur transition hover:bg-white hover:text-[#351711]"><ChevronLeft className="size-4" /></button>
            <button type="button" aria-label="Next featured find" onClick={() => move(1)} className="flex size-10 items-center justify-center rounded-full border border-white/50 bg-black/15 text-white backdrop-blur transition hover:bg-white hover:text-[#351711]"><ChevronRight className="size-4" /></button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
