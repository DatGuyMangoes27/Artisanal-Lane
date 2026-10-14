import { NextResponse } from "next/server";

import {
  PASSWORD_RECOVERY_COOKIE,
  PASSWORD_RECOVERY_COOKIE_MAX_AGE,
} from "@/lib/auth/password-recovery";
import { readSessionAuthMethods } from "@/lib/auth/auth-hash";
import { createClient } from "@/lib/supabase/server";

/**
 * Completes an email link that carries its session in the URL fragment
 * (resets sent from the Supabase dashboard or older app builds). The session
 * replaces whoever was signed in on this browser, and a recovery link is
 * marked so /reset-password lets the person choose a new password.
 */
export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as {
    accessToken?: unknown;
    refreshToken?: unknown;
    type?: unknown;
  } | null;
  const accessToken = typeof body?.accessToken === "string" ? body.accessToken : "";
  const refreshToken = typeof body?.refreshToken === "string" ? body.refreshToken : "";
  if (!accessToken || !refreshToken) {
    return NextResponse.json({ ok: false }, { status: 400 });
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.setSession({
    access_token: accessToken,
    refresh_token: refreshToken,
  });
  if (error || !data.user || !data.session) {
    return NextResponse.json({ ok: false }, { status: 401 });
  }

  const methods = readSessionAuthMethods(data.session.access_token);
  const isRecovery =
    body?.type === "recovery" &&
    methods.some((method) => method === "recovery" || method === "otp" || method === "magiclink");

  const response = NextResponse.json({ ok: true, recovery: isRecovery });
  if (isRecovery) {
    response.cookies.set(PASSWORD_RECOVERY_COOKIE, "pending", {
      httpOnly: true,
      maxAge: PASSWORD_RECOVERY_COOKIE_MAX_AGE,
      path: "/",
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
    });
  }
  return response;
}
