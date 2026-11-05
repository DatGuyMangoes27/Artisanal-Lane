// Browser-only: shrinks phone photos before they are uploaded through a
// Server Action. A single phone photo is often 2-5 MB, so two or three of them
// went over the application's 4 MB limit and applicants could not submit.

export const SHRUNK_IMAGE_MAX_SIDE = 1600;
export const SHRUNK_IMAGE_QUALITY = 0.82;

/** Width and height that fit inside maxSide, keeping the aspect ratio. */
export function fitWithin(width: number, height: number, maxSide = SHRUNK_IMAGE_MAX_SIDE) {
  const longest = Math.max(width, height);
  if (longest <= maxSide || longest === 0) return { width, height };
  const scale = maxSide / longest;
  return { width: Math.round(width * scale), height: Math.round(height * scale) };
}

function jpegName(name: string) {
  const base = name.replace(/\.[^./\\]+$/, "") || "photo";
  return `${base}.jpg`;
}

/**
 * Returns a JPEG no larger than SHRUNK_IMAGE_MAX_SIDE on its longest side.
 * Falls back to the original file when the browser can't decode it, or when
 * the original is already smaller than the result.
 */
export async function shrinkImage(file: File): Promise<File> {
  if (typeof document === "undefined" || typeof createImageBitmap !== "function") return file;
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file);
  } catch {
    return file;
  }
  try {
    const { width, height } = fitWithin(bitmap.width, bitmap.height);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    if (!context) return file;
    // JPEG has no transparency: paint white behind PNGs.
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, width, height);
    context.drawImage(bitmap, 0, 0, width, height);
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, "image/jpeg", SHRUNK_IMAGE_QUALITY),
    );
    if (!blob) return file;
    const allowedOriginal = ["image/jpeg", "image/png", "image/webp"].includes(file.type);
    if (allowedOriginal && blob.size >= file.size) return file;
    return new File([blob], jpegName(file.name), {
      type: "image/jpeg",
      lastModified: file.lastModified,
    });
  } finally {
    bitmap.close();
  }
}
