import "server-only";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

import {
  mapBuyerChatMessage,
  mapBuyerChatThread,
  type BuyerChatMessage,
  type BuyerChatThread,
} from "./messages";

const chatThreadSelect = `
  id,
  shop_id,
  buyer_id,
  vendor_id,
  kind,
  last_message_preview,
  last_message_type,
  last_message_sender_id,
  last_message_at,
  created_at,
  updated_at,
  shops(name, logo_url),
  buyer:profiles!chat_threads_buyer_id_fkey(display_name, avatar_url),
  vendor:profiles!chat_threads_vendor_id_fkey(display_name, avatar_url),
  chat_thread_reads(participant_id, last_read_at, last_read_message_id)
`;

const chatMessageSelect = `
  id,
  thread_id,
  sender_id,
  body,
  message_type,
  attachment_url,
  attachment_path,
  attachment_name,
  attachment_mime,
  attachment_size_bytes,
  created_at
`;

export async function requireBuyerMessageSession(redirectTo: string) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect(`/login?redirect=${encodeURIComponent(redirectTo)}`);
  }

  return { supabase, user };
}

export async function listBuyerChatThreads(userId: string): Promise<BuyerChatThread[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("chat_threads")
    .select(chatThreadSelect)
    .eq("buyer_id", userId)
    .eq("kind", "buyer_vendor")
    .order("last_message_at", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load buyer messages", { cause: error });
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) =>
    mapBuyerChatThread(row, userId),
  );
}

export async function getBuyerChatThread(
  userId: string,
  threadId: string,
): Promise<BuyerChatThread | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("chat_threads")
    .select(chatThreadSelect)
    .eq("id", threadId)
    .eq("buyer_id", userId)
    .eq("kind", "buyer_vendor")
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load buyer message thread", { cause: error });
  }

  return data ? mapBuyerChatThread(data as Record<string, unknown>, userId) : null;
}

export async function listBuyerChatMessages(threadId: string): Promise<BuyerChatMessage[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("chat_messages")
    .select(chatMessageSelect)
    .eq("thread_id", threadId)
    .order("created_at", { ascending: true });

  if (error) {
    throw new Error("Failed to load buyer message history", { cause: error });
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map(mapBuyerChatMessage);
}

export async function markBuyerThreadRead(userId: string, threadId: string) {
  const supabase = await createClient();
  const { data: latestMessage } = await supabase
    .from("chat_messages")
    .select("id")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle<{ id: string }>();

  await supabase.from("chat_thread_reads").upsert(
    {
      thread_id: threadId,
      participant_id: userId,
      last_read_message_id: latestMessage?.id ?? null,
      last_read_at: new Date().toISOString(),
    },
    { onConflict: "thread_id,participant_id" },
  );
}
