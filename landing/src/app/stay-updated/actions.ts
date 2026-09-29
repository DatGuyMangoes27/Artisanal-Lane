"use server";
import { createHmac, randomUUID } from "node:crypto";
import { headers } from "next/headers";
import { createAdminClient } from "@/lib/supabase/admin";
import { getSupabaseServiceRoleKey } from "@/lib/supabase/env";

type State = { message: string; unsubscribeUrl?: string };
export async function subscribeToUpdates(_state: State, form: FormData): Promise<State> {
  const email = String(form.get("email") ?? "").trim().toLowerCase();
  if (String(form.get("website") ?? "")) return { message: "Thank you. Your request has been received." };
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { message: "Please enter a valid email address." };
  if (form.get("consent") !== "on") return { message: "Please tick the consent box to sign up." };
  try {
    const requestHeaders = await headers();
    const ip = requestHeaders.get("x-nf-client-connection-ip") ?? requestHeaders.get("x-forwarded-for")?.split(",")[0] ?? "unknown";
    const requestHash = createHmac("sha256", getSupabaseServiceRoleKey()).update(`${new Date().toISOString().slice(0,10)}:${ip}`).digest("hex");
    const admin = createAdminClient();
    const { count, error: countError } = await admin.from("newsletter_subscribers").select("email", { count: "exact", head: true }).eq("request_hash", requestHash).gte("subscribed_at", new Date(Date.now() - 3600000).toISOString());
    if (countError) throw countError;
    if ((count ?? 0) >= 5) return { message: "Too many requests. Please try again later." };
    const token = randomUUID();
    const { error } = await admin.from("newsletter_subscribers").insert({ email, request_hash: requestHash, unsubscribe_token: token });
    // Never expose an existing subscriber's token or reverse an unsubscribe.
    if (error?.code === "23505") return { message: "Thank you. If this address is new, your signup has been saved. Existing preferences remain unchanged." };
    if (error) throw error;
    return { message: "Thank you! Your signup is saved. No account needed. Keep the link below if you want to unsubscribe; future promotional emails will also include an unsubscribe link.", unsubscribeUrl: `/stay-updated/unsubscribe?token=${token}` };
  } catch { return { message: "We could not save your signup right now. Please try again shortly." }; }
}

export async function unsubscribeFromUpdates(_state: State, form: FormData): Promise<State> {
  const token = String(form.get("token") ?? "");
  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(token)) return { message: "This unsubscribe link is invalid." };
  try {
    const { error } = await createAdminClient().from("newsletter_subscribers").update({ unsubscribed_at: new Date().toISOString() }).eq("unsubscribe_token", token);
    if (error) throw error;
    return { message: "You have been unsubscribed from promotional email updates." };
  } catch { return { message: "We could not update your preference. Please try again." }; }
}
