import { describe, expect, it } from "vitest";

import { APP_STORE_URL, GOOGLE_PLAY_URL, appStorePlatform } from "./app-links";

describe("app links", () => {
  it("point at the Artisan Lane listings", () => {
    expect(APP_STORE_URL).toContain("id6760702139");
    expect(GOOGLE_PLAY_URL).toContain("id=com.artisanallane.artisanal_lane");
  });

  it("suggests the right store for the phone", () => {
    expect(appStorePlatform("Mozilla/5.0 (iPhone; CPU iPhone OS 26_6 like Mac OS X)")).toBe("ios");
    expect(appStorePlatform("Mozilla/5.0 (Linux; Android 16; SM-A556E)")).toBe("android");
    expect(appStorePlatform("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")).toBe("other");
  });
});
