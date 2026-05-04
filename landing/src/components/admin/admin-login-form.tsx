"use client";

import { FormEvent, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/browser";

export function AdminLoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [rememberMe, setRememberMe] = useState(false);
  const [error, setError] = useState<string | null>(
    searchParams.get("error") === "unauthorized"
      ? "Your account is not allowed to access the admin panel."
      : null,
  );
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);

    const supabase = createClient({ rememberSession: rememberMe });
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (signInError) {
      setError(signInError.message);
      setSubmitting(false);
      return;
    }

    router.replace("/admin");
    router.refresh();
  }

  return (
    <Card className="w-full max-w-md border-artisan-clay/70 bg-white/95 shadow-xl">
      <CardHeader className="space-y-2">
        <CardTitle className="text-3xl text-artisan-sienna">
          Admin Sign In
        </CardTitle>
        <CardDescription>
          Sign in with an admin account to manage the marketplace.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form className="space-y-4" onSubmit={handleSubmit}>
          <div className="space-y-2">
            <label className="text-sm font-medium text-artisan-sienna" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              className="w-full rounded-lg border border-artisan-clay bg-white px-3 py-2 text-sm outline-none ring-0 transition focus:border-artisan-terracotta"
              type="email"
              autoComplete="email"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-artisan-sienna" htmlFor="password">
              Password
            </label>
            <input
              id="password"
              className="w-full rounded-lg border border-artisan-clay bg-white px-3 py-2 text-sm outline-none ring-0 transition focus:border-artisan-terracotta"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
          </div>
          <label className="flex items-center gap-3 text-sm text-artisan-sienna">
            <input
              className="h-4 w-4 rounded border-artisan-clay text-artisan-terracotta focus:ring-artisan-terracotta"
              type="checkbox"
              checked={rememberMe}
              onChange={(event) => setRememberMe(event.target.checked)}
            />
            <span>Remember me on this device</span>
          </label>
          {error ? (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {error}
            </p>
          ) : null}
          <Button
            className="w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
            disabled={submitting}
            type="submit"
          >
            {submitting ? "Signing in..." : "Sign In"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
