// Email links sent outside the website's own PKCE flow (Supabase dashboard,
// older app builds) put the session in the URL fragment. These helpers read it.

export const AUTH_HASH_STORAGE_KEY = "artisan-lane-auth-hash";

export type AuthHashResult =
  | { kind: "session"; accessToken: string; refreshToken: string; type: string | null }
  | { kind: "error"; type: string | null }
  | null;

export function parseAuthHash(hash: string): AuthHashResult {
  const params = new URLSearchParams(hash.startsWith("#") ? hash.slice(1) : hash);
  const type = params.get("type");
  if (params.get("error") || params.get("error_description")) {
    return { kind: "error", type };
  }
  const accessToken = params.get("access_token");
  const refreshToken = params.get("refresh_token");
  if (!accessToken || !refreshToken) {
    return null;
  }
  return { kind: "session", accessToken, refreshToken, type };
}

/** The `amr` methods in a Supabase access token (no signature check; call after the server validated it). */
export function readSessionAuthMethods(accessToken: string): string[] {
  try {
    const payload = accessToken.split(".")[1] ?? "";
    const json = JSON.parse(
      Buffer.from(payload.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8"),
    ) as { amr?: Array<{ method?: unknown }> };
    return (json.amr ?? [])
      .map((entry) => (typeof entry.method === "string" ? entry.method : ""))
      .filter(Boolean);
  } catch {
    return [];
  }
}
