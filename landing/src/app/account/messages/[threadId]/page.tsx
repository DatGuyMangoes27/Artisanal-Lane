import Link from "next/link";
import { notFound } from "next/navigation";

import { sendBuyerMessage } from "@/app/account/messages/actions";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  getBuyerChatThread,
  listBuyerChatMessages,
  markBuyerThreadRead,
  requireBuyerMessageSession,
} from "@/lib/marketplace/message-data";
import { getMessagePreview } from "@/lib/marketplace/messages";

type BuyerMessageThreadPageProps = {
  params: Promise<{
    threadId: string;
  }>;
};

export default async function BuyerMessageThreadPage({ params }: BuyerMessageThreadPageProps) {
  const { threadId } = await params;
  const { user } = await requireBuyerMessageSession(`/account/messages/${threadId}`);
  const thread = await getBuyerChatThread(user.id, threadId);

  if (!thread) {
    notFound();
  }

  const messages = await listBuyerChatMessages(thread.id);
  await markBuyerThreadRead(user.id, thread.id);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-4xl px-4 py-10 sm:px-6 lg:px-8">
        <Button asChild variant="ghost" className="mb-6 rounded-full">
          <Link href="/account/messages">Back to messages</Link>
        </Button>

        <Card className="border-artisan-clay bg-card">
          <CardContent className="p-6">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
                  Conversation
                </p>
                <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground">
                  {thread.shopName}
                </h1>
                {thread.vendorDisplayName ? (
                  <p className="mt-2 text-sm text-muted-foreground">
                    Artisan: {thread.vendorDisplayName}
                  </p>
                ) : null}
              </div>
              <Badge variant="outline">Buyer chat</Badge>
            </div>
          </CardContent>
        </Card>

        <section className="mt-6 space-y-4">
          {messages.length === 0 ? (
            <Card className="border-artisan-clay bg-card">
              <CardContent className="p-6 text-center text-muted-foreground">
                No messages yet. Send the first message to this artisan.
              </CardContent>
            </Card>
          ) : (
            messages.map((message) => {
              const mine = message.isMine(user.id);
              return (
                <div key={message.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                  <div
                    className={`max-w-[78%] rounded-3xl px-5 py-3 text-sm shadow-sm ${
                      mine
                        ? "bg-artisan-terracotta text-white"
                        : "border border-artisan-clay bg-card text-foreground"
                    }`}
                  >
                    <p className="whitespace-pre-wrap leading-6">{getMessagePreview(message)}</p>
                    <p className={`mt-2 text-xs ${mine ? "text-white/75" : "text-muted-foreground"}`}>
                      {new Date(message.createdAt).toLocaleString("en-ZA", {
                        month: "short",
                        day: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </p>
                  </div>
                </div>
              );
            })
          )}
        </section>

        <Card className="mt-6 border-artisan-clay bg-card">
          <CardContent className="p-4">
            <form action={sendBuyerMessage} className="flex flex-col gap-3 sm:flex-row">
              <input type="hidden" name="threadId" value={thread.id} />
              <label className="sr-only" htmlFor="message-body">Message</label>
              <textarea
                id="message-body"
                name="body"
                required
                rows={2}
                placeholder="Type your message..."
                className="min-h-12 flex-1 rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm outline-none transition focus:border-artisan-terracotta"
              />
              <Button type="submit" className="rounded-full sm:self-end">
                Send
              </Button>
            </form>
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
