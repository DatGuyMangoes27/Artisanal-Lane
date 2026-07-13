"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { getPasswordRecoveryRedirectUrl } from "@/lib/auth/password-recovery";
import { createClient } from "@/lib/supabase/browser";

export function ForgotPasswordForm() {
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);

    const supabase = createClient();
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(
      email.trim(),
      {
        redirectTo: getPasswordRecoveryRedirectUrl(window.location.origin),
      },
    );

    setSubmitting(false);

    if (resetError) {
      setError(
        resetError.status === 429
          ? "Too many reset attempts. Please wait a few minutes and try again."
          : "We could not send the reset email. Check the address and try again.",
      );
      return;
    }

    setSent(true);
  }

  return (
    <Card className="w-full max-w-md border-artisan-clay/70 bg-white/95 shadow-xl">
      <CardHeader className="space-y-2">
        <CardTitle className="text-3xl text-artisan-sienna">
          Reset your password
        </CardTitle>
        <CardDescription>
          Enter the email used for your Artisan Lane account. We will send you a
          secure link to choose a new password.
        </CardDescription>
      </CardHeader>
      <CardContent>
        {sent ? (
          <div className="space-y-4">
            <p
              aria-live="polite"
              className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-3 text-sm text-emerald-800"
            >
              If an account exists for <strong>{email.trim()}</strong>, a password
              reset link is on its way. Check your inbox and spam folder.
            </p>
            <Button
              className="w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
              onClick={() => {
                setSent(false);
                setError(null);
              }}
              type="button"
            >
              Send another link
            </Button>
          </div>
        ) : (
          <form className="space-y-4" onSubmit={handleSubmit}>
            <label className="block space-y-2 text-sm font-medium text-artisan-sienna">
              Email
              <input
                autoComplete="email"
                autoFocus
                className="w-full rounded-lg border border-artisan-clay bg-white px-3 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
                onChange={(event) => setEmail(event.target.value)}
                required
                type="email"
                value={email}
              />
            </label>
            {error ? (
              <p
                aria-live="polite"
                className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700"
              >
                {error}
              </p>
            ) : null}
            <Button
              className="w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
              disabled={submitting}
              type="submit"
            >
              {submitting ? "Sending reset link..." : "Email me a reset link"}
            </Button>
          </form>
        )}
        <Button asChild className="mt-3 w-full" variant="ghost">
          <Link href="/login">Back to sign in</Link>
        </Button>
      </CardContent>
    </Card>
  );
}
