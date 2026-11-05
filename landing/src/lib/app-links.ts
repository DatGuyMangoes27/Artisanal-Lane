// Store listings for the Artisan Lane mobile app.

export const APP_STORE_APP_ID = "6760702139";
export const APP_STORE_URL = `https://apps.apple.com/za/app/artisan-lane/id${APP_STORE_APP_ID}`;
export const GOOGLE_PLAY_URL =
  "https://play.google.com/store/apps/details?id=com.artisanallane.artisanal_lane";

export type AppStorePlatform = "ios" | "android" | "other";

/** Which store to suggest for a browser's user agent. */
export function appStorePlatform(userAgent: string): AppStorePlatform {
  if (/iPhone|iPad|iPod/i.test(userAgent)) return "ios";
  // iPadOS reports itself as a Mac with touch support; treated as other here.
  if (/Android/i.test(userAgent)) return "android";
  return "other";
}
