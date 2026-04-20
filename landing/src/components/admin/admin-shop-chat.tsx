"use client";

import { useActionState, useEffect, useRef } from "react";
import Link from "next/link";
import { Paperclip, SendHorizonal } from "lucide-react";

import { sendAdminShopMessage } from "@/app/admin/actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { initialAdminActionState } from "@/lib/admin-action-state";
import { cn } from "@/lib/utils";

type ChatMessageView = {
  id: string;
  body: string | null;
  sender_id: string;
  created_at: string;
  attachment_url: string | null;
  attachment_name: string | null;
  attachment_mime: string | null;
  sender: {
    id: string;
    display_name: string | null;
    email: string | null;
  } | null;
};

export function AdminShopChatPanel({
  shopId,
  adminUserId,
  messages,
  shopName,
  vendorName,
  emptyHint,
}: {
  shopId: string;
  adminUserId: string;
  messages: ChatMessageView[];
  shopName: string;
  vendorName: string;
  emptyHint?: string;
}) {
  return (
    <div className="flex h-[min(70vh,640px)] flex-col overflow-hidden rounded-3xl border border-artisan-clay bg-white">
      <ChatMessagesList
        messages={messages}
        adminUserId={adminUserId}
        shopName={shopName}
        vendorName={vendorName}
        emptyHint={emptyHint}
      />
      <AdminShopChatComposer shopId={shopId} />
    </div>
  );
}

function ChatMessagesList({
  messages,
  adminUserId,
  shopName,
  vendorName,
  emptyHint,
}: {
  messages: ChatMessageView[];
  adminUserId: string;
  shopName: string;
  vendorName: string;
  emptyHint?: string;
}) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    el.scrollTop = el.scrollHeight;
  }, [messages.length]);

  if (messages.length === 0) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-2 px-6 py-10 text-center">
        <p className="text-lg font-semibold text-artisan-sienna">
          Say hello to {shopName}
        </p>
        <p className="max-w-md text-sm text-muted-foreground">
          {emptyHint ??
            `This conversation will appear in ${vendorName}'s vendor inbox as "Artisan Lane Support".`}
        </p>
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      className="flex-1 space-y-3 overflow-y-auto bg-artisan-bone/40 p-5"
    >
      {messages.map((message) => {
        const isMine = message.sender_id === adminUserId;
        const senderLabel = isMine
          ? "You (Artisan Lane)"
          : message.sender?.display_name ??
            message.sender?.email ??
            vendorName;
        return (
          <div
            key={message.id}
            className={cn(
              "flex",
              isMine ? "justify-end" : "justify-start",
            )}
          >
            <div
              className={cn(
                "max-w-[85%] rounded-2xl px-4 py-3 text-sm shadow-sm",
                isMine
                  ? "bg-artisan-terracotta text-white"
                  : "border border-artisan-clay bg-white text-artisan-sienna",
              )}
            >
              <p
                className={cn(
                  "mb-1 text-[11px] font-semibold uppercase tracking-wide",
                  isMine ? "text-white/80" : "text-artisan-terracotta",
                )}
              >
                {senderLabel}
              </p>
              {message.attachment_url ? (
                <Link
                  className={cn(
                    "mb-2 flex items-center gap-2 rounded-xl px-3 py-2 text-xs",
                    isMine ? "bg-white/15" : "bg-artisan-bone",
                  )}
                  href={message.attachment_url}
                  target="_blank"
                >
                  <Paperclip className="h-3.5 w-3.5" />
                  {message.attachment_name ?? "Attachment"}
                </Link>
              ) : null}
              {message.body ? (
                <p className="whitespace-pre-wrap leading-relaxed">
                  {message.body}
                </p>
              ) : null}
              <p
                className={cn(
                  "mt-2 text-[10px]",
                  isMine ? "text-white/70" : "text-muted-foreground",
                )}
              >
                {new Date(message.created_at).toLocaleString()}
              </p>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function AdminShopChatComposer({ shopId }: { shopId: string }) {
  const [state, formAction, pending] = useActionState(
    sendAdminShopMessage,
    initialAdminActionState,
  );
  const formRef = useRef<HTMLFormElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (state.status === "success") {
      formRef.current?.reset();
      textareaRef.current?.focus();
    }
  }, [state.status, state.savedAt]);

  return (
    <form
      action={formAction}
      className="space-y-2 border-t border-artisan-clay/60 bg-white p-4"
      ref={formRef}
    >
      <input name="shopId" type="hidden" value={shopId} />
      <textarea
        className="min-h-24 w-full resize-y rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm text-artisan-sienna outline-none transition focus:border-artisan-terracotta"
        name="body"
        placeholder="Write a message to this shop..."
        ref={textareaRef}
      />
      <div className="flex flex-wrap items-center justify-between gap-3">
        <AdminActionFeedback state={state} />
        <Button
          className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
          disabled={pending}
          type="submit"
        >
          <SendHorizonal className="h-4 w-4" />
          {pending ? "Sending..." : "Send message"}
        </Button>
      </div>
    </form>
  );
}
