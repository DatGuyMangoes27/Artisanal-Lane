import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

export const CHAT_ATTACHMENT_MAX_BYTES = 10 * 1024 * 1024;
export const CHAT_ATTACHMENT_ACCEPT = "image/jpeg,image/png,image/webp,image/gif";

const allowedImageTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
]);

function safeFileName(name: string) {
  return name.replace(/[^A-Za-z0-9._-]/g, "_").slice(-120) || "photo";
}

export function getChatAttachmentFile(formData: FormData) {
  const value = formData.get("attachment");
  if (!(value instanceof File) || value.size === 0) return null;
  if (!allowedImageTypes.has(value.type)) {
    throw new Error("Attach a JPEG, PNG, WebP, or GIF image.");
  }
  if (value.size > CHAT_ATTACHMENT_MAX_BYTES) {
    throw new Error("Message photos must be 10 MB or smaller.");
  }
  return value;
}

export async function uploadChatAttachment({
  supabase,
  threadId,
  senderId,
  file,
}: {
  supabase: SupabaseClient;
  threadId: string;
  senderId: string;
  file: File;
}) {
  const path = `${threadId}/${senderId}/${crypto.randomUUID()}-${safeFileName(file.name)}`;
  const { error } = await supabase.storage.from("chat-attachments").upload(path, file, {
    contentType: file.type,
    upsert: false,
  });
  if (error) {
    throw new Error("Unable to upload the message photo.", { cause: error });
  }

  return {
    path,
    name: file.name,
    mime: file.type,
    sizeBytes: file.size,
  };
}

export async function removeChatAttachment(
  supabase: SupabaseClient,
  path: string | null | undefined,
) {
  if (!path) return;
  await supabase.storage.from("chat-attachments").remove([path]);
}
