"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  getAccountHomeHref,
  getLoginIntentCopy,
  getLoginRedirectForIntent,
  normalizeLoginIntent,
} from "@/lib/marketplace/account-routing";
import { createClient } from "@/lib/supabase/browser";

export function BuyerLoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const intent = normalizeLoginIntent(searchParams.get("intent"));
  const explicitRedirect = searchParams.get("redirect");
  const redirectTo = explicitRedirect || getLoginRedirectForIntent(intent);
  const copy = getLoginIntentCopy(intent);
  const [mode, setMode] = useState<"sign-in" | "sign-up">("sign-in");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    setMessage(null);

    const supabase = createClient();
    const result =
      mode === "sign-in"
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signUp({
            email,
            password,
            options: {
              data: { requested_role: copy.requestedRole },
            },
          });

    if (result.error) {
      setError(result.error.message);
      setSubmitting(false);
      return;
    }

    if (mode === "sign-up" && !result.data.session) {
      setMessage("Account created. Please check your email to confirm it, then sign in.");
      setMode("sign-in");
      setSubmitting(false);
      return;
    }

    const userId = result.data.user?.id ?? null;
    const userEmail = result.data.user?.email ?? email;

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", userId ?? "")
      .maybeSingle();
    let profileRole = (profile as { role?: string | null } | null)?.role ?? null;

    // Web sign-up only creates the auth user; without a matching profiles row the
    // server-rendered account pages crash. Create it here (mirroring the mobile
    // app) so brand-new buyers land in their account, and so existing
    // profile-less accounts self-heal on their next sign in. Never overwrite an
    // existing role.
    if (userId && !profile) {
      const { error: profileError } = await supabase.from("profiles").upsert({
        id: userId,
        role: "buyer",
        email: userEmail,
        display_name: userEmail ? userEmail.split("@")[0] : null,
      });
      if (!profileError) {
        profileRole = "buyer";
      }
    }

    const roleHome = getAccountHomeHref(profileRole ?? copy.requestedRole);
    const nextPath = profileRole === "buyer" && explicitRedirect ? redirectTo : roleHome;

    router.replace(nextPath);
    router.refresh();
  }

  return (
    <Card className="w-full max-w-md border-artisan-clay/70 bg-white/95 shadow-xl">
      <CardHeader className="space-y-2">
        <CardTitle className="text-3xl text-artisan-sienna">
          {mode === "sign-in" ? copy.title : copy.createTitle}
        </CardTitle>
        <CardDescription>
          {copy.description}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div className="mb-4 grid grid-cols-2 gap-2 rounded-2xl bg-artisan-bone/60 p-1">
          <Button
            asChild
            type="button"
            variant={intent === "buyer" ? "default" : "ghost"}
            className={intent === "buyer" ? "bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark" : ""}
          >
            <Link href={`/login?intent=buyer${explicitRedirect ? `&redirect=${encodeURIComponent(explicitRedirect)}` : ""}`}>
              Buyer
            </Link>
          </Button>
          <Button
            asChild
            type="button"
            variant={intent === "vendor" ? "default" : "ghost"}
            className={intent === "vendor" ? "bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark" : ""}
          >
            <Link href={`/login?intent=vendor${explicitRedirect ? `&redirect=${encodeURIComponent(explicitRedirect)}` : ""}`}>
              Vendor
            </Link>
          </Button>
        </div>
        <form className="space-y-4" onSubmit={handleSubmit}>
          <label className="block space-y-2 text-sm font-medium text-artisan-sienna">
            Email
            <input
              className="w-full rounded-lg border border-artisan-clay bg-white px-3 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
          </label>
          <label className="block space-y-2 text-sm font-medium text-artisan-sienna">
            Password
            <input
              className="w-full rounded-lg border border-artisan-clay bg-white px-3 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
              type="password"
              autoComplete={mode === "sign-in" ? "current-password" : "new-password"}
              required
              minLength={6}
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
          </label>
          {error ? (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {error}
            </p>
          ) : null}
          {message ? (
            <p className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
              {message}
            </p>
          ) : null}
          <Button
            className="w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
            disabled={submitting}
            type="submit"
          >
            {submitting
              ? "Please wait..."
              : mode === "sign-in"
                ? "Sign in"
                : "Create account"}
          </Button>
        </form>
        <Button
          type="button"
          variant="ghost"
          className="mt-3 w-full"
          onClick={() => {
            setError(null);
            setMessage(null);
            setMode((current) => (current === "sign-in" ? "sign-up" : "sign-in"));
          }}
        >
          {mode === "sign-in" ? "Need an account? Create one" : "Already have an account? Sign in"}
        </Button>
      </CardContent>
    </Card>
  );
}
