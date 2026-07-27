import { describe, expect, it } from "vitest";

import {
  getLearningEmbedUrl,
  getSpotifyEmbedUrl,
  getYouTubeEmbedUrl,
  isDirectVideoUrl,
} from "./learning-embed";

describe("learning embed helpers", () => {
  it("converts YouTube watch, short, and youtu.be links to embeds", () => {
    expect(getYouTubeEmbedUrl("https://www.youtube.com/watch?v=abc123")).toBe(
      "https://www.youtube.com/embed/abc123",
    );
    expect(getYouTubeEmbedUrl("https://youtu.be/abc123")).toBe(
      "https://www.youtube.com/embed/abc123",
    );
    expect(getYouTubeEmbedUrl("https://www.youtube.com/shorts/abc123")).toBe(
      "https://www.youtube.com/embed/abc123",
    );
  });

  it("converts Spotify show/episode links to embeds", () => {
    expect(getSpotifyEmbedUrl("https://open.spotify.com/episode/xyz789")).toBe(
      "https://open.spotify.com/embed/episode/xyz789",
    );
    expect(
      getSpotifyEmbedUrl("https://open.spotify.com/show/showid?si=1"),
    ).toBe("https://open.spotify.com/embed/show/showid");
  });

  it("returns null for unsupported or invalid URLs", () => {
    expect(getYouTubeEmbedUrl("https://example.com/video")).toBeNull();
    expect(getSpotifyEmbedUrl("not a url")).toBeNull();
    expect(getLearningEmbedUrl("https://example.com/article")).toBeNull();
  });

  it("recognises direct video files even when the URL has query parameters", () => {
    expect(
      isDirectVideoUrl(
        "https://example.supabase.co/storage/v1/object/public/videos/tutorial.mp4?version=2",
      ),
    ).toBe(true);
    expect(isDirectVideoUrl("https://youtu.be/abc123")).toBe(false);
    expect(isDirectVideoUrl("not a url")).toBe(false);
  });
});
