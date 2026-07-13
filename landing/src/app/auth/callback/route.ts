import { NextResponse } from "next/server";

import {
  PASSWORD_RECOVERY_COOKIE,
  PASSWORD_RECOVERY_COOKIE_MAX_AGE,
  PASSWORD_RECOVERY_PATH,
  getPasswordRecoveryRequestOrigin,
} from "@/lib/auth/password-recovery";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const publicOrigin = getPasswordRecoveryRequestOrigin(
    request.url,
    request.headers,
  );
  const resetUrl = new URL(PASSWORD_RECOVERY_PATH, publicOrigin);

  if (!code) {
    resetUrl.searchParams.set("status", "invalid-link");
    return NextResponse.redirect(resetUrl);
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    resetUrl.searchParams.set("status", "invalid-link");
    return NextResponse.redirect(resetUrl);
  }

  const response = NextResponse.redirect(resetUrl);
  response.cookies.set(PASSWORD_RECOVERY_COOKIE, "pending", {
    httpOnly: true,
    maxAge: PASSWORD_RECOVERY_COOKIE_MAX_AGE,
    path: "/",
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });

  return response;
}
