"use client";

import { ChevronLeft, ChevronRight } from "lucide-react";
import { useRef, type ReactNode } from "react";

import { Button } from "@/components/ui/button";

export function ProductCarousel({ children }: { children: ReactNode }) {
  const railRef = useRef<HTMLDivElement>(null);

  function scrollByProduct(direction: "previous" | "next") {
    const rail = railRef.current;
    if (!rail) {
      return;
    }

    const firstCard = rail.firstElementChild as HTMLElement | null;
    const scrollAmount = firstCard
      ? firstCard.offsetWidth + 24
      : rail.clientWidth;

    rail.scrollBy({
      left: direction === "next" ? scrollAmount : -scrollAmount,
      behavior: "smooth",
    });
  }

  return (
    <div className="relative">
      <Button
        type="button"
        variant="secondary"
        size="icon"
        aria-label="Previous fresh arrival"
        className="absolute -left-3 top-1/2 z-10 hidden size-11 -translate-y-1/2 rounded-full border border-artisan-clay bg-card/95 shadow-lg backdrop-blur md:inline-flex"
        onClick={() => scrollByProduct("previous")}
      >
        <ChevronLeft />
      </Button>
      <div
        ref={railRef}
        className="grid grid-flow-col auto-cols-[minmax(16rem,78%)] items-stretch gap-6 overflow-x-hidden scroll-smooth sm:auto-cols-[minmax(16rem,45%)] lg:auto-cols-[calc((100%-4.5rem)/4)]"
      >
        {children}
      </div>
      <Button
        type="button"
        variant="secondary"
        size="icon"
        aria-label="Next fresh arrival"
        className="absolute -right-3 top-1/2 z-10 hidden size-11 -translate-y-1/2 rounded-full border border-artisan-clay bg-card/95 shadow-lg backdrop-blur md:inline-flex"
        onClick={() => scrollByProduct("next")}
      >
        <ChevronRight />
      </Button>
      <div className="mt-4 flex justify-center gap-2 md:hidden">
        <Button
          type="button"
          variant="outline"
          size="icon"
          aria-label="Previous fresh arrival"
          className="rounded-full"
          onClick={() => scrollByProduct("previous")}
        >
          <ChevronLeft />
        </Button>
        <Button
          type="button"
          variant="outline"
          size="icon"
          aria-label="Next fresh arrival"
          className="rounded-full"
          onClick={() => scrollByProduct("next")}
        >
          <ChevronRight />
        </Button>
      </div>
    </div>
  );
}
