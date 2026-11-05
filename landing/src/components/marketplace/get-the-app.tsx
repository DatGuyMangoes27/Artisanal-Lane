"use client";

import { useEffect, useState } from "react";
import { Bell, Compass, Smartphone, X } from "lucide-react";

import {
  APP_STORE_URL,
  GOOGLE_PLAY_URL,
  appStorePlatform,
  type AppStorePlatform,
} from "@/lib/app-links";

const DISMISS_KEY = "artisan-lane:get-app-dismissed";

function usePlatform() {
  const [platform, setPlatform] = useState<AppStorePlatform>("other");
  useEffect(() => {
    window.setTimeout(() => setPlatform(appStorePlatform(navigator.userAgent)), 0);
  }, []);
  return platform;
}

function StoreLink({
  href,
  small,
  big,
  tone,
}: {
  href: string;
  small: string;
  big: string;
  tone: "light" | "dark";
}) {
  const colours =
    tone === "dark"
      ? "bg-[#FFF8F0] text-[#351711] hover:bg-[#EAD9CA]"
      : "bg-[#351711] text-[#FFF8F0] hover:bg-[#50160F]";
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex min-w-[168px] items-center gap-3 rounded-2xl px-5 py-2.5 transition ${colours}`}
    >
      <Smartphone className="size-5 shrink-0" aria-hidden />
      <span className="grid text-left leading-tight">
        <span className="text-[10px] uppercase tracking-wider opacity-80">{small}</span>
        <span className="text-base font-semibold">{big}</span>
      </span>
    </a>
  );
}

/** Both store buttons, the phone's own store first. */
export function AppStoreButtons({
  tone = "light",
  className = "",
}: {
  tone?: "light" | "dark";
  className?: string;
}) {
  const platform = usePlatform();
  const apple = (
    <StoreLink key="ios" href={APP_STORE_URL} small="Download on the" big="App Store" tone={tone} />
  );
  const google = (
    <StoreLink key="android" href={GOOGLE_PLAY_URL} small="Get it on" big="Google Play" tone={tone} />
  );
  return (
    <div className={`flex flex-wrap gap-3 ${className}`}>
      {platform === "android" ? [google, apple] : [apple, google]}
    </div>
  );
}

/** Home page band encouraging app downloads. */
export function GetTheAppSection() {
  const perks = [
    [Compass, "Discover by swiping", "Love it or skip it, and the app learns your taste"],
    [Smartphone, "Follow your makers", "Stories, new pieces and behind-the-scenes posts"],
    [Bell, "Order updates", "Delivery tracking and messages, straight to your phone"],
  ] as const;
  return (
    <section
      id="get-the-app"
      className="bg-[linear-gradient(135deg,#351711_0%,#50160F_62%,#314522_135%)] px-5 py-16 text-[#FFF8F0] sm:px-8 sm:py-20"
    >
      <div className="mx-auto grid max-w-[1200px] items-center gap-10 lg:grid-cols-[1.1fr_1fr]">
        <div>
          <p className="text-[11px] font-bold uppercase tracking-[0.22em] text-[#E5B35A]">
            Get the app
          </p>
          <h2 className="mt-3 font-serif text-3xl font-bold leading-tight sm:text-4xl">
            Artisan Lane in your pocket
          </h2>
          <p className="mt-4 max-w-xl leading-7 text-[#EAD9CA]">
            The app is the best way to find handmade pieces you&apos;ll love. It&apos;s free on
            iPhone and Android.
          </p>
          <AppStoreButtons tone="dark" className="mt-7" />
        </div>
        <ul className="grid gap-4">
          {perks.map(([Icon, title, body]) => (
            <li key={title} className="flex gap-4 rounded-2xl bg-white/5 p-4">
              <Icon className="mt-0.5 size-5 shrink-0 text-[#E5B35A]" aria-hidden />
              <span>
                <span className="block font-semibold">{title}</span>
                <span className="text-sm text-[#EAD9CA]">{body}</span>
              </span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

/**
 * Slim, dismissible prompt for phone visitors (product pages and after
 * payment). Hidden on computers, and for a month once dismissed.
 */
export function GetTheAppStrip({ message }: { message: string }) {
  const platform = usePlatform();
  const [dismissed, setDismissed] = useState(true);

  useEffect(() => {
    let hidden = false;
    try {
      const at = Number(window.localStorage.getItem(DISMISS_KEY) ?? 0);
      hidden = Date.now() - at < 30 * 24 * 60 * 60 * 1000;
    } catch {
      hidden = false;
    }
    window.setTimeout(() => setDismissed(hidden), 0);
  }, []);

  if (dismissed || platform === "other") return null;

  function dismiss() {
    setDismissed(true);
    try {
      window.localStorage.setItem(DISMISS_KEY, String(Date.now()));
    } catch {
      // Private browsing: it simply shows again next time.
    }
  }

  const href = platform === "ios" ? APP_STORE_URL : GOOGLE_PLAY_URL;
  return (
    <div className="mx-auto my-4 flex max-w-3xl items-center gap-3 rounded-2xl border border-artisan-clay bg-white p-3 text-left shadow-sm">
      <Smartphone className="size-6 shrink-0 text-artisan-terracotta" aria-hidden />
      <p className="flex-1 text-sm text-[#351711]">{message}</p>
      <a
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className="shrink-0 rounded-full bg-artisan-terracotta px-4 py-2 text-sm font-semibold text-white"
      >
        Get the app
      </a>
      <button
        type="button"
        onClick={dismiss}
        aria-label="Hide"
        className="shrink-0 rounded-full p-1 text-muted-foreground hover:bg-artisan-bone/50"
      >
        <X className="size-4" aria-hidden />
      </button>
    </div>
  );
}
