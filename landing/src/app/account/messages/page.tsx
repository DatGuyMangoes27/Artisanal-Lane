import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  listBuyerChatThreads,
  requireBuyerMessageSession,
} from "@/lib/marketplace/message-data";
import { isThreadUnread } from "@/lib/marketplace/messages";

export default async function BuyerMessagesPage() {
  const { user } = await requireBuyerMessageSession("/account/messages");
  const threads = await listBuyerChatThreads(user.id);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-5xl px-4 py-10 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
              Buyer account
            </p>
            <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
              Messages
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        {threads.length === 0 ? (
          <Card className="mt-10 border-artisan-clay bg-card text-center">
            <CardContent className="p-8">
              <h2 className="font-serif text-2xl font-bold text-foreground">No messages yet</h2>
              <p className="mt-2 text-muted-foreground">
                Start a conversation from a product, shop, or order page when you need help from an
                artisan.
              </p>
              <Button asChild className="mt-6 rounded-full">
                <Link href="/shop">Browse artisans</Link>
              </Button>
            </CardContent>
          </Card>
        ) : (
          <div className="mt-10 space-y-4">
            {threads.map((thread) => {
              const unread = isThreadUnread(thread, user.id);
              return (
                <Link
                  key={thread.id}
                  href={`/account/messages/${thread.id}`}
                  className="block rounded-[2rem] focus:outline-none focus:ring-2 focus:ring-artisan-terracotta"
                >
                  <Card className="border-artisan-clay bg-card transition hover:border-artisan-terracotta">
                    <CardContent className="grid gap-4 p-6 md:grid-cols-[1fr_auto] md:items-center">
                      <div>
                        <div className="flex flex-wrap items-center gap-3">
                          <h2 className="font-serif text-2xl font-bold text-foreground">
                            {thread.shopName}
                          </h2>
                          {unread ? <Badge>New</Badge> : null}
                        </div>
                        <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">
                          {thread.previewText}
                        </p>
                      </div>
                      <p className="text-sm text-muted-foreground md:text-right">
                        {thread.lastMessageAt
                          ? new Date(thread.lastMessageAt).toLocaleDateString("en-ZA", {
                              month: "short",
                              day: "numeric",
                            })
                          : "No messages"}
                      </p>
                    </CardContent>
                  </Card>
                </Link>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}
