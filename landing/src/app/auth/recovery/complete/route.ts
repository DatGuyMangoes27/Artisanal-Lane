import { NextResponse } from "next/server";

import { PASSWORD_RECOVERY_COOKIE } from "@/lib/auth/password-recovery";

export async function POST() {
  const response = NextResponse.json({ ok: true });
  response.cookies.set(PASSWORD_RECOVERY_COOKIE, "", {
    expires: new Date(0),
    httpOnly: true,
    maxAge: 0,
    path: "/",
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });
  return response;
}
