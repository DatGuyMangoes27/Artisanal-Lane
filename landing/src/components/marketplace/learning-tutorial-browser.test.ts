import { describe, expect, it } from "vitest";

import {
  getTutorialPlatform,
  getTutorialSection,
} from "../../lib/learning-tutorials";

describe("learning tutorial browser", () => {
  it("separates website tutorials from app tutorials", () => {
    expect(
      getTutorialPlatform({
        title: "Website: Create a simple product",
        author: "Artisan Lane Web",
        contentUrl: "https://example.com/web-landscape/tutorial.mp4",
      }),
    ).toBe("website");

    expect(
      getTutorialPlatform({
        title: "Create a simple product",
        author: "Artisan Lane",
        contentUrl: "https://example.com/app/tutorial.mp4",
      }),
    ).toBe("app");
  });

  it("uses the same sections for app and website sort orders", () => {
    expect(getTutorialSection(1)).toBe("getting-started");
    expect(getTutorialSection(101)).toBe("getting-started");
    expect(getTutorialSection(9)).toBe("products");
    expect(getTutorialSection(109)).toBe("products");
    expect(getTutorialSection(18)).toBe("orders");
    expect(getTutorialSection(118)).toBe("orders");
    expect(getTutorialSection(24)).toBe("shop-management");
    expect(getTutorialSection(124)).toBe("shop-management");
  });
});
