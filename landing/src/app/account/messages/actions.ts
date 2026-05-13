"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";

async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?redirect=/account/messages");
  }

  return { supabase, user };
}

export async function createBuyerThreadForShop(formData: FormData) {
  const shopId = String(formData.get("shopId") ?? "").trim();
  const redirectTo = String(formData.get("redirectTo") ?? "/account/messages");

  if (!shopId) {
    redirect(redirectTo);
  }

  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("get_or_create_buyer_chat_thread", {
    shop_uuid: shopId,
  });

  if (error || typeof data !== "string") {
    redirect(`${redirectTo}?messageError=${encodeURIComponent(error?.message ?? "Could not open chat")}`);
  }

  redirect(`/account/messages/${data}`);
}

export async function sendBuyerMessage(formData: FormData) {
  const threadId = String(formData.get("threadId") ?? "").trim();
  const body = String(formData.get("body") ?? "").trim();

  if (!threadId) {
    redirect("/account/messages");
  }

  if (!body) {
    redirect(`/account/messages/${threadId}`);
  }

  const { supabase, user } = await requireUser();
  const { error } = await supabase.from("chat_messages").insert({
    thread_id: threadId,
    sender_id: user.id,
    body,
    message_type: "text",
  });

  if (!error) {
    await supabase.from("chat_thread_reads").upsert(
      {
        thread_id: threadId,
        participant_id: user.id,
        last_read_at: new Date().toISOString(),
      },
      { onConflict: "thread_id,participant_id" },
    );
  }

  revalidatePath("/account/messages");
  revalidatePath(`/account/messages/${threadId}`);
  redirect(`/account/messages/${threadId}`);
}
