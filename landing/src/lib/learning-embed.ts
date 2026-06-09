// Pure helpers for turning a pasted share URL into an embeddable player URL.
// Kept dependency-free so they can run on the server and in unit tests.

export function getYouTubeEmbedUrl(url: string): string | null {
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.replace(/^www\./, "");

    if (host === "youtu.be") {
      const id = parsed.pathname.slice(1);
      return id ? `https://www.youtube.com/embed/${id}` : null;
    }

    if (host === "youtube.com" || host === "m.youtube.com") {
      if (parsed.pathname === "/watch") {
        const id = parsed.searchParams.get("v");
        return id ? `https://www.youtube.com/embed/${id}` : null;
      }
      const match = parsed.pathname.match(/^\/(embed|shorts)\/([^/?]+)/);
      if (match) {
        return `https://www.youtube.com/embed/${match[2]}`;
      }
    }

    return null;
  } catch {
    return null;
  }
}

export function getSpotifyEmbedUrl(url: string): string | null {
  try {
    const parsed = new URL(url);
    if (parsed.hostname.replace(/^www\./, "") !== "open.spotify.com") {
      return null;
    }
    if (parsed.pathname.startsWith("/embed/")) {
      return `https://open.spotify.com${parsed.pathname}`;
    }
    const match = parsed.pathname.match(
      /^\/(track|episode|show|playlist|album)\/([^/?]+)/,
    );
    if (match) {
      return `https://open.spotify.com/embed/${match[1]}/${match[2]}`;
    }
    return null;
  } catch {
    return null;
  }
}

export function getLearningEmbedUrl(url: string): string | null {
  return getYouTubeEmbedUrl(url) ?? getSpotifyEmbedUrl(url);
}
