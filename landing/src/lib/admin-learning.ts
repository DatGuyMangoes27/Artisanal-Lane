// Pure validation helpers for the admin Learning Hub / artisan Library form.

// Server Actions are capped at 5 MB in next.config.ts (bodySizeLimit); keep the
// thumbnail well under that so the rest of the form fields still fit.
export const MAX_LEARNING_THUMBNAIL_BYTES = 4 * 1024 * 1024;

const allowedImageExtensions = new Set(["jpg", "jpeg", "png", "webp", "gif", "avif"]);

const contentTypeByExtension: Record<string, string> = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
  gif: "image/gif",
  avif: "image/avif",
};

export function normalizeLearningContentUrl(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error("A valid link (https://...) is required.");
  }
  // Be forgiving when an admin pastes "www.example.com/..." without a scheme.
  const candidate = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  let parsed: URL;
  try {
    parsed = new URL(candidate);
  } catch {
    throw new Error("A valid link (https://...) is required.");
  }
  if (
    (parsed.protocol !== "https:" && parsed.protocol !== "http:") ||
    !parsed.hostname.includes(".")
  ) {
    throw new Error("A valid link (https://...) is required.");
  }
  return parsed.toString();
}

export function parseLearningSortOrder(value: string): number {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

/**
 * Validates an uploaded thumbnail and returns a safe storage extension and
 * content type. Browsers often send an empty or generic mime type, so fall back
 * to the file extension.
 */
export function resolveLearningThumbnail(file: {
  name: string;
  type: string;
  size: number;
}): { extension: string; contentType: string } {
  if (file.size > MAX_LEARNING_THUMBNAIL_BYTES) {
    throw new Error("Thumbnail is too large. Please upload an image under 4 MB.");
  }

  const rawExtension = file.name.includes(".")
    ? (file.name.split(".").pop() ?? "").toLowerCase().replace(/[^a-z0-9]/g, "")
    : "";
  const mime = (file.type || "").toLowerCase();

  if (mime.startsWith("image/")) {
    const fromMime = mime.replace("image/", "").replace("jpeg", "jpg").replace(/[^a-z0-9]/g, "");
    const extension = allowedImageExtensions.has(rawExtension)
      ? rawExtension
      : allowedImageExtensions.has(fromMime)
        ? fromMime
        : null;
    if (extension) {
      return { extension, contentType: mime };
    }
  } else if (allowedImageExtensions.has(rawExtension)) {
    return { extension: rawExtension, contentType: contentTypeByExtension[rawExtension] };
  }

  throw new Error("Thumbnail must be a JPG, PNG, WebP, GIF or AVIF image.");
}
