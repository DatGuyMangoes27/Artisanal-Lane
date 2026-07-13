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
import {
  PASSWORD_MIN_LENGTH,
  validateRecoveryPassword,
} from "@/lib/auth/password-recovery";
import { createClient } from "@/lib/supabase/browser";

type ResetPasswordFormProps = {
  canReset: boolean;
};

export function ResetPasswordForm({ canReset }: ResetPasswordFormProps) {
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [complete, setComplete] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    const validationError = validateRecoveryPassword(password, confirmation);
    if (validationError) {
      setError(validationError);
      return;
    }

    setSubmitting(true);
    const supabase = createClient();
    const { error: updateError } = await supabase.auth.updateUser({ password });

    if (updateError) {
      setError(
        updateError.message ||
          "We could not update your password. Request a new reset link and try again.",
      );
      setSubmitting(false);
      return;
    }

    await fetch("/auth/recovery/complete", { method: "POST" });
    const { error: signOutError } = await supabase.auth.signOut({
      scope: "global",
    });
    if (signOutError) {
      await supabase.auth.signOut({ scope: "local" });
    }

    setComplete(true);
    setSubmitting(false);
  }

  if (!canReset) {
    return (
      <Card className="w-full max-w-md border-artisan-clay/70 bg-white/95 shadow-xl">
        <CardHeader className="space-y-2">
          <CardTitle className="text-3xl text-artisan-sienna">
            This link is no longer valid
          </CardTitle>
          <CardDescription>
            Password reset links expire and can only be used once. Request a new
            link to continue.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <Button
            asChild
            className="w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
          >
            <Link href="/forgot-password">Request a new reset link</Link>
          </Button>
          <Button asChild className="w-full" variant="ghost">
            <Link href="/login">Back to sign in</Link>
          </Button>
        </CardContent>
      </Card>
    );
  }

  if (complete) {
    return (
      <Card className="w-full max-w-md border-artisan-clay/70 bg-white/95 shadow-xl">
        <CardHeader className="space-y-2">
          <CardTitle className="text-3xl text-artisan-sienna">
            Password updated
          </CardTitle>
          <CardDescription>
            Your new password is ready. For your security, you have been signed
            out and can now sign in again.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Button
            asChild
            className="w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
          >
            <Link href="/login">Sign in with your new password</Link>
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="w-full max-w-md border-artisan-clay/70 bg-white/95 shadow-xl">
      <CardHeader className="space-y-2">
        <CardTitle className="text-3xl text-artisan-sienna">
          Choose a new password
        </CardTitle>
        <CardDescription>
          Use at least {PASSWORD_MIN_LENGTH} characters and avoid reusing a
          password from another account.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form className="space-y-4" onSubmit={handleSubmit}>
          <label className="block space-y-2 text-sm font-medium text-artisan-sienna">
            New password
            <input
              autoComplete="new-password"
              autoFocus
              className="w-full rounded-lg border border-artisan-clay bg-white px-3 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
              minLength={PASSWORD_MIN_LENGTH}
              onChange={(event) => setPassword(event.target.value)}
              required
              type="password"
              value={password}
            />
          </label>
          <label className="block space-y-2 text-sm font-medium text-artisan-sienna">
            Confirm new password
            <input
              autoComplete="new-password"
              className="w-full rounded-lg border border-artisan-clay bg-white px-3 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
              minLength={PASSWORD_MIN_LENGTH}
              onChange={(event) => setConfirmation(event.target.value)}
              required
              type="password"
              value={confirmation}
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
            {submitting ? "Updating password..." : "Update password"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
