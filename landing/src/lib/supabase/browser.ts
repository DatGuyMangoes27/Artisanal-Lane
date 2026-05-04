import { createBrowserClient } from "@supabase/ssr";

import { getSupabaseAnonKey, getSupabaseUrl } from "@/lib/supabase/env";

type BrowserClient = ReturnType<typeof createBrowserClient>;

type CreateClientOptions = {
  rememberSession?: boolean;
};

type BrowserCookieOptions = {
  domain?: string;
  expires?: Date;
  httpOnly?: boolean;
  maxAge?: number;
  path?: string;
  sameSite?: boolean | "lax" | "strict" | "none";
  secure?: boolean;
};

let browserClient: BrowserClient | undefined;

function getAllCookies() {
  if (typeof document === "undefined" || !document.cookie) {
    return [];
  }

  return document.cookie
    .split(";")
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const separatorIndex = entry.indexOf("=");
      const name = separatorIndex >= 0 ? entry.slice(0, separatorIndex) : entry;
      const value = separatorIndex >= 0 ? entry.slice(separatorIndex + 1) : "";

      return {
        name: decodeURIComponent(name),
        value: decodeURIComponent(value),
      };
    });
}

function serializeCookie(
  name: string,
  value: string,
  options: BrowserCookieOptions,
) {
  const segments = [
    `${encodeURIComponent(name)}=${encodeURIComponent(value)}`,
  ];

  if (options.maxAge != null) {
    segments.push(`Max-Age=${options.maxAge}`);
  }
  if (options.domain) {
    segments.push(`Domain=${options.domain}`);
  }
  if (options.path) {
    segments.push(`Path=${options.path}`);
  }
  if (options.expires) {
    segments.push(`Expires=${options.expires.toUTCString()}`);
  }
  if (options.sameSite) {
    const sameSite =
      options.sameSite === true
        ? "Strict"
        : `${options.sameSite}`.charAt(0).toUpperCase() +
          `${options.sameSite}`.slice(1);
    segments.push(`SameSite=${sameSite}`);
  }
  if (options.secure) {
    segments.push("Secure");
  }

  return segments.join("; ");
}

function createSessionCookieClient() {
  return createBrowserClient(getSupabaseUrl(), getSupabaseAnonKey(), {
    isSingleton: false,
    cookies: {
      getAll: getAllCookies,
      setAll: (cookies) => {
        cookies.forEach(({ name, value, options }) => {
          const cookieOptions =
            value && options.maxAge !== 0
              ? {
                  ...options,
                  expires: undefined,
                  maxAge: undefined,
                }
              : options;

          document.cookie = serializeCookie(
            name,
            value,
            cookieOptions as BrowserCookieOptions,
          );
        });
      },
    },
  });
}

export function createClient(options: CreateClientOptions = {}) {
  const rememberSession = options.rememberSession ?? true;

  if (!rememberSession) {
    return createSessionCookieClient();
  }

  if (!browserClient) {
    browserClient = createBrowserClient(getSupabaseUrl(), getSupabaseAnonKey());
  }

  return browserClient;
}
