"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { sendChatMessagePushNotifications } from "@/lib/push-notifications";
import {
  getChatAttachmentFile,
  removeChatAttachment,
  uploadChatAttachment,
} from "@/lib/marketplace/chat-attachment-storage";

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
  const attachmentFile = getChatAttachmentFile(formData);

  if (!threadId) {
    redirect("/account/messages");
  }

  if (!body && !attachmentFile) {
    redirect(`/account/messages/${threadId}`);
  }

  const { supabase, user } = await requireUser();
  const attachment = attachmentFile
    ? await uploadChatAttachment({
        supabase,
        threadId,
        senderId: user.id,
        file: attachmentFile,
      })
    : null;
  const { data: message, error } = await supabase
    .from("chat_messages")
    .insert({
      thread_id: threadId,
      sender_id: user.id,
      body: body || null,
      message_type: body && attachment ? "text_with_attachment" : attachment ? "attachment" : "text",
      attachment_path: attachment?.path ?? null,
      attachment_name: attachment?.name ?? null,
      attachment_mime: attachment?.mime ?? null,
      attachment_size_bytes: attachment?.sizeBytes ?? null,
    })
    .select("id")
    .single();

  if (error) {
    await removeChatAttachment(supabase, attachment?.path);
  } else {
    if (message?.id) {
      await sendChatMessagePushNotifications([message.id]);
    }
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
