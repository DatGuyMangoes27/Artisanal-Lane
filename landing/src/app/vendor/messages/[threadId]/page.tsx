import { notFound } from "next/navigation";

import { Button } from "@/components/ui/button";
import { ChatSafetyNotice } from "@/components/marketplace/chat-safety-notice";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { sendVendorMessage } from "@/app/vendor/actions";
import {
  getVendorChatThread,
  listVendorChatMessages,
  requireVendorSession,
} from "@/lib/marketplace/vendor-data";

export default async function VendorMessageThreadPage({
  params,
}: {
  params: Promise<{ threadId: string }>;
}) {
  const { threadId } = await params;
  const { user } = await requireVendorSession(`/vendor/messages/${threadId}`);
  const [thread, messages] = await Promise.all([
    getVendorChatThread(user.id, threadId),
    listVendorChatMessages(threadId),
  ]);

  if (!thread) {
    notFound();
  }

  return (
    <div>
      <VendorPageHeader
        eyebrow={thread.isAdminThread ? "Artisan Lane" : "Community"}
        title={
          thread.isAdminThread
            ? "Artisan Lane Support"
            : thread.buyerName ?? thread.buyerEmail ?? "Buyer conversation"
        }
        description={
          thread.isAdminThread
            ? "Messages from the Artisan Lane team about your shop."
            : "Keep buyer conversations inside the shared chat thread."
        }
      />
      <VendorPanel title="Conversation">
        <div className="mb-4">
          <ChatSafetyNotice />
        </div>
        <div className="space-y-3">
          {messages.map((message) => {
            const mine = message.senderId === user.id;
            return (
              <div key={message.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-xl rounded-3xl px-4 py-3 text-sm ${mine ? "bg-artisan-terracotta text-white" : "bg-artisan-bone text-artisan-sienna"}`}>
                  <p>{message.body ?? message.attachmentName ?? "Attachment"}</p>
                  <p className={`mt-2 text-xs ${mine ? "text-white/70" : "text-muted-foreground"}`}>
                    {new Intl.DateTimeFormat("en-ZA", { dateStyle: "medium", timeStyle: "short" }).format(new Date(message.createdAt))}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
        <form action={sendVendorMessage} className="mt-6 grid gap-3">
          <input type="hidden" name="threadId" value={thread.id} />
          <textarea name="body" required placeholder="Write a reply..." className="min-h-28 rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <Button className="w-fit rounded-full bg-artisan-terracotta px-8 hover:bg-artisan-terracotta/90">
            Send message
          </Button>
        </form>
      </VendorPanel>
    </div>
  );
}
