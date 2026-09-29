"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export async function saveEmailUpdates(_state: { message: string }, form: FormData) {
  const supabase = await createClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return { message: "Please sign in again to save your preference." };
  if (!user.email_confirmed_at) return { message: "Please confirm your account email before subscribing." };
  const enabled = form.get("enabled") === "on";
  // This is a user-owned preference, never an authorization claim.
  const { error } = await supabase.auth.updateUser({ data: {
    artisan_lane_email_updates: {
      enabled,
      email: user.email,
      updated_at: new Date().toISOString(),
      consent_version: "2026-09",
      source: "website-account",
    },
  } });
  if (error) return { message: "We could not save your preference. Please try again." };
  revalidatePath("/account/email-updates");
  return { message: enabled ? "You're on the list. Your email-updates preference is saved." : "You are unsubscribed from promotional email updates." };
}
