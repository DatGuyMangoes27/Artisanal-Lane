import { describe, expect, it } from "vitest";

import {
  MAX_LEARNING_THUMBNAIL_BYTES,
  normalizeLearningContentUrl,
  parseLearningSortOrder,
  resolveLearningThumbnail,
} from "./admin-learning";

describe("normalizeLearningContentUrl", () => {
  it("accepts https and http links", () => {
    expect(normalizeLearningContentUrl(" https://youtu.be/abc ")).toBe("https://youtu.be/abc");
  });
  it("adds https when the scheme is missing", () => {
    expect(normalizeLearningContentUrl("www.example.com/post")).toBe("https://www.example.com/post");
  });
  it("rejects junk and non-http schemes", () => {
    expect(() => normalizeLearningContentUrl("")).toThrow();
    expect(() => normalizeLearningContentUrl("javascript:alert(1)")).toThrow();
    expect(() => normalizeLearningContentUrl("not a url")).toThrow();
  });
});

describe("parseLearningSortOrder", () => {
  it("defaults to 0", () => {
    expect(parseLearningSortOrder("")).toBe(0);
    expect(parseLearningSortOrder("abc")).toBe(0);
    expect(parseLearningSortOrder("7")).toBe(7);
  });
});

describe("resolveLearningThumbnail", () => {
  it("accepts a normal image", () => {
    expect(resolveLearningThumbnail({ name: "Cover.JPG", type: "image/jpeg", size: 1000 })).toEqual({
      extension: "jpg",
      contentType: "image/jpeg",
    });
  });
  it("falls back to the extension when the mime type is empty", () => {
    expect(resolveLearningThumbnail({ name: "cover.png", type: "", size: 1000 })).toEqual({
      extension: "png",
      contentType: "image/png",
    });
  });
  it("sanitises odd extensions via the mime type", () => {
    expect(resolveLearningThumbnail({ name: "cover.jpg?x=1", type: "image/webp", size: 10 }).extension).toBe("webp");
  });
  it("rejects oversized and non-image files", () => {
    expect(() =>
      resolveLearningThumbnail({ name: "a.jpg", type: "image/jpeg", size: MAX_LEARNING_THUMBNAIL_BYTES + 1 }),
    ).toThrow(/too large/);
    expect(() => resolveLearningThumbnail({ name: "a.pdf", type: "application/pdf", size: 10 })).toThrow(
      /JPG, PNG/,
    );
  });
});
