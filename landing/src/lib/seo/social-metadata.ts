import type { Metadata } from "next";

const SITE_URL = "https://artisanlanesa.co.za";
const DEFAULT_IMAGE = "/logo.png";

function plainSummary(text: string | null | undefined, max = 200) {
  const clean = (text ?? "").replace(/\s+/g, " ").trim();
  if (clean.length <= max) return clean;
  return `${clean.slice(0, max - 1).trimEnd()}…`;
}

/**
 * Page metadata including the Open Graph / Twitter tags that social apps
 * (WhatsApp, Facebook, Instagram, X) use for link previews. Without these a
 * page inherits the site-wide card, so every shared shop or product link
 * previewed as the homepage.
 */
export function socialMetadata(input: {
  title: string;
  description: string | null | undefined;
  /** Path of the page, e.g. /shops/clay-studio/ (trailing slash matches the site). */
  path: string;
  image: string | null | undefined;
  type?: "website" | "article";
}): Metadata {
  const description = plainSummary(input.description) || "Handmade on Artisan Lane.";
  const image = input.image?.trim() || DEFAULT_IMAGE;
  const url = new URL(input.path, SITE_URL).toString();
  return {
    title: `${input.title} | Artisan Lane`,
    description,
    alternates: { canonical: url },
    openGraph: {
      title: input.title,
      description,
      url,
      siteName: "Artisan Lane",
      type: input.type ?? "website",
      locale: "en_ZA",
      images: [{ url: image, alt: input.title }],
    },
    twitter: {
      card: "summary_large_image",
      title: input.title,
      description,
      images: [image],
    },
  };
}
