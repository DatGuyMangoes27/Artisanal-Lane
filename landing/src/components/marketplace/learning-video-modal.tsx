"use client";

import {
  type MouseEvent,
  type ReactNode,
  useEffect,
  useId,
  useRef,
  useState,
} from "react";
import { ExternalLink, X } from "lucide-react";

import { getLearningEmbedUrl, isDirectVideoUrl } from "@/lib/learning-embed";

type LearningVideoModalProps = {
  children: ReactNode;
  className?: string;
  title: string;
  url: string;
  thumbnailUrl?: string | null;
};

export function LearningVideoModal({
  children,
  className,
  title,
  url,
  thumbnailUrl,
}: LearningVideoModalProps) {
  const [open, setOpen] = useState(false);
  const titleId = useId();
  const triggerRef = useRef<HTMLAnchorElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const embedUrl = getLearningEmbedUrl(url);
  const directVideo = isDirectVideoUrl(url);

  useEffect(() => {
    if (!open) return;

    const previousOverflow = document.body.style.overflow;
    const trigger = triggerRef.current;
    document.body.style.overflow = "hidden";
    closeRef.current?.focus();

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
      }
    }

    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
      trigger?.focus();
    };
  }, [open]);

  function openModal(event: MouseEvent<HTMLAnchorElement>) {
    event.preventDefault();
    setOpen(true);
  }

  return (
    <>
      <a
        ref={triggerRef}
        href={url}
        onClick={openModal}
        className={className}
        aria-haspopup="dialog"
      >
        {children}
      </a>

      {open ? (
        <div
          className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 p-3 backdrop-blur-sm sm:p-6"
          onMouseDown={(event) => {
            if (event.currentTarget === event.target) setOpen(false);
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            className="flex max-h-[calc(100dvh-1.5rem)] w-full max-w-5xl flex-col overflow-hidden rounded-2xl border border-white/15 bg-artisan-bone shadow-2xl sm:max-h-[calc(100dvh-3rem)] sm:rounded-3xl"
          >
            <div className="flex items-center justify-between gap-4 border-b border-artisan-clay px-4 py-3 sm:px-6">
              <h2
                id={titleId}
                className="line-clamp-2 text-base font-semibold text-artisan-sienna sm:text-lg"
              >
                {title}
              </h2>
              <button
                ref={closeRef}
                type="button"
                onClick={() => setOpen(false)}
                className="shrink-0 rounded-full p-2 text-artisan-sienna transition hover:bg-artisan-clay/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-artisan-terracotta"
                aria-label="Close video"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="flex min-h-0 flex-1 items-center justify-center bg-black">
              {directVideo ? (
                <video
                  src={url}
                  poster={thumbnailUrl ?? undefined}
                  controls
                  autoPlay
                  playsInline
                  preload="metadata"
                  className="max-h-[calc(100dvh-8rem)] w-full object-contain sm:max-h-[calc(100dvh-10rem)]"
                >
                  Your browser does not support embedded video playback.
                </video>
              ) : (
                <iframe
                  src={embedUrl ?? url}
                  title={title}
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowFullScreen
                  className="aspect-video max-h-[calc(100dvh-8rem)] w-full sm:max-h-[calc(100dvh-10rem)]"
                />
              )}
            </div>

            <div className="flex justify-end border-t border-artisan-clay px-4 py-3 sm:px-6">
              <a
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-1.5 text-xs font-semibold text-artisan-terracotta hover:underline"
              >
                Open video in a new tab
                <ExternalLink className="h-3.5 w-3.5" />
              </a>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
