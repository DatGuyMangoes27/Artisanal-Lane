"use client";

import Image from "next/image";
import { useCallback, useEffect, useRef, useState } from "react";
import { ChevronLeft, ChevronRight, Maximize2, Minus, Plus, X } from "lucide-react";

import { Badge } from "@/components/ui/badge";

type ProductGalleryProps = {
  images: string[];
  title: string;
  onSale?: boolean;
};

const MAX_ZOOM = 4;
const MIN_ZOOM = 1;

export function ProductGallery({ images, title, onSale = false }: ProductGalleryProps) {
  const gallery = images.length > 0 ? images : ["/marketplace-placeholder.svg"];
  const [activeIndex, setActiveIndex] = useState(0);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const dragState = useRef<{ x: number; y: number; ox: number; oy: number } | null>(null);

  const active = Math.min(activeIndex, gallery.length - 1);

  const resetView = useCallback(() => {
    setZoom(1);
    setOffset({ x: 0, y: 0 });
  }, []);

  const openLightbox = useCallback(() => {
    resetView();
    setLightboxOpen(true);
  }, [resetView]);

  const closeLightbox = useCallback(() => {
    setLightboxOpen(false);
    resetView();
  }, [resetView]);

  const goTo = useCallback(
    (next: number) => {
      const count = gallery.length;
      setActiveIndex(((next % count) + count) % count);
      resetView();
    },
    [gallery.length, resetView],
  );

  useEffect(() => {
    if (!lightboxOpen) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") closeLightbox();
      if (event.key === "ArrowRight") goTo(active + 1);
      if (event.key === "ArrowLeft") goTo(active - 1);
    }
    document.addEventListener("keydown", onKey);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = previousOverflow;
    };
  }, [lightboxOpen, active, goTo, closeLightbox]);

  const adjustZoom = useCallback((delta: number) => {
    setZoom((prev) => {
      const next = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, prev + delta));
      if (next === MIN_ZOOM) setOffset({ x: 0, y: 0 });
      return Number(next.toFixed(2));
    });
  }, []);

  return (
    <section aria-label={`${title} image gallery`} className="space-y-4">
      <button
        type="button"
        onClick={openLightbox}
        className="group relative block aspect-square w-full overflow-hidden rounded-[2rem] border border-artisan-clay bg-secondary shadow-sm"
        aria-label="Open image viewer"
      >
        <Image
          src={gallery[active]}
          alt={title}
          fill
          priority
          sizes="(min-width: 1024px) 50vw, 100vw"
          className="object-cover transition duration-300 group-hover:scale-[1.02]"
        />
        {onSale ? <Badge className="absolute left-4 top-4 bg-artisan-terracotta">Sale</Badge> : null}
        <span className="absolute bottom-4 right-4 flex items-center gap-1.5 rounded-full bg-black/55 px-3 py-1.5 text-xs font-medium text-white opacity-0 transition group-hover:opacity-100">
          <Maximize2 className="h-3.5 w-3.5" />
          Tap to zoom
        </span>
      </button>

      {gallery.length > 1 ? (
        <div className="grid grid-cols-4 gap-3">
          {gallery.slice(0, 8).map((image, index) => (
            <button
              key={`${image}-${index}`}
              type="button"
              onClick={() => setActiveIndex(index)}
              className={`relative aspect-square overflow-hidden rounded-2xl border bg-secondary transition ${
                index === active
                  ? "border-artisan-terracotta ring-2 ring-artisan-terracotta/40"
                  : "border-artisan-clay hover:border-artisan-terracotta"
              }`}
              aria-label={`View image ${index + 1}`}
            >
              <Image
                src={image}
                alt={`${title} image ${index + 1}`}
                fill
                sizes="25vw"
                className="object-cover"
              />
            </button>
          ))}
        </div>
      ) : null}

      {lightboxOpen ? (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/90"
          onClick={closeLightbox}
        >
          <button
            type="button"
            onClick={closeLightbox}
            className="absolute right-4 top-4 z-10 rounded-full bg-white/10 p-2 text-white transition hover:bg-white/20"
            aria-label="Close viewer"
          >
            <X className="h-6 w-6" />
          </button>

          {gallery.length > 1 ? (
            <>
              <button
                type="button"
                onClick={(event) => {
                  event.stopPropagation();
                  goTo(active - 1);
                }}
                className="absolute left-3 top-1/2 z-10 -translate-y-1/2 rounded-full bg-white/10 p-2 text-white transition hover:bg-white/20"
                aria-label="Previous image"
              >
                <ChevronLeft className="h-7 w-7" />
              </button>
              <button
                type="button"
                onClick={(event) => {
                  event.stopPropagation();
                  goTo(active + 1);
                }}
                className="absolute right-3 top-1/2 z-10 -translate-y-1/2 rounded-full bg-white/10 p-2 text-white transition hover:bg-white/20"
                aria-label="Next image"
              >
                <ChevronRight className="h-7 w-7" />
              </button>
            </>
          ) : null}

          <div
            className="flex h-full w-full items-center justify-center overflow-hidden p-6"
            onClick={(event) => event.stopPropagation()}
            onWheel={(event) => adjustZoom(event.deltaY < 0 ? 0.2 : -0.2)}
            onDoubleClick={() => (zoom > MIN_ZOOM ? resetView() : adjustZoom(1))}
            onPointerDown={(event) => {
              if (zoom <= MIN_ZOOM) return;
              dragState.current = {
                x: event.clientX,
                y: event.clientY,
                ox: offset.x,
                oy: offset.y,
              };
              (event.target as HTMLElement).setPointerCapture?.(event.pointerId);
            }}
            onPointerMove={(event) => {
              if (!dragState.current) return;
              setOffset({
                x: dragState.current.ox + (event.clientX - dragState.current.x),
                y: dragState.current.oy + (event.clientY - dragState.current.y),
              });
            }}
            onPointerUp={() => {
              dragState.current = null;
            }}
            style={{ cursor: zoom > MIN_ZOOM ? "grab" : "zoom-in" }}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={gallery[active]}
              alt={`${title} enlarged`}
              draggable={false}
              className="max-h-full max-w-full select-none object-contain transition-transform duration-100"
              style={{
                transform: `translate(${offset.x}px, ${offset.y}px) scale(${zoom})`,
              }}
            />
          </div>

          <div
            className="absolute bottom-5 left-1/2 z-10 flex -translate-x-1/2 items-center gap-2 rounded-full bg-white/10 px-3 py-2 text-white"
            onClick={(event) => event.stopPropagation()}
          >
            <button
              type="button"
              onClick={() => adjustZoom(-0.3)}
              className="rounded-full p-1.5 transition hover:bg-white/20"
              aria-label="Zoom out"
            >
              <Minus className="h-5 w-5" />
            </button>
            <span className="min-w-12 text-center text-sm tabular-nums">{Math.round(zoom * 100)}%</span>
            <button
              type="button"
              onClick={() => adjustZoom(0.3)}
              className="rounded-full p-1.5 transition hover:bg-white/20"
              aria-label="Zoom in"
            >
              <Plus className="h-5 w-5" />
            </button>
          </div>
        </div>
      ) : null}
    </section>
  );
}
