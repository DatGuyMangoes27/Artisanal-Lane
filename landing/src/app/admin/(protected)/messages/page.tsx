import Link from "next/link";
import { ArrowRight, MessageSquare, Store } from "lucide-react";

import { AdminChatAutoRefresh } from "@/components/admin/admin-chat-auto-refresh";
import { AdminPageHeader, PanelCard } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { listAdminShopThreads } from "@/lib/admin-messaging";

function formatTimestamp(value: string | null) {
  if (!value) return "No messages yet";
  return new Date(value).toLocaleString();
}

export default async function AdminMessagesPage() {
  const threads = await listAdminShopThreads();

  return (
    <>
      <AdminChatAutoRefresh intervalMs={6000} />
      <AdminPageHeader
        eyebrow="Shop Messaging"
        title="Shop Conversations"
        description="Every chat the admin team has started with a shop. Open any card to continue a conversation, or pick a shop from the stores page to start a new one."
        actions={
          <Button
            asChild
            className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
          >
            <Link href="/admin/shops">
              <Store className="h-4 w-4" />
              Start a new chat
            </Link>
          </Button>
        }
      />

      <PanelCard
        title="Active shop chats"
        description="Newest activity first. Admin conversations appear in the shop vendor's normal inbox."
      >
        {threads.length === 0 ? (
          <div className="flex flex-col items-center gap-3 rounded-3xl border border-dashed border-artisan-clay bg-white p-10 text-center">
            <MessageSquare className="h-8 w-8 text-artisan-terracotta" />
            <p className="text-lg font-semibold text-artisan-sienna">
              No shop conversations yet
            </p>
            <p className="max-w-md text-sm text-muted-foreground">
              Head to the <Link className="underline" href="/admin/shops">Shops</Link>{" "}
              page and click &ldquo;Message store&rdquo; to kick off a chat with
              any seller.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {threads.map((thread) => {
              const lastSender = thread.last_message_sender_id === thread.buyer_id
                ? thread.admin?.display_name ?? "Admin"
                : thread.vendor?.display_name ?? "Vendor";
              return (
                <div
                  key={thread.id}
                  className="flex flex-col gap-4 rounded-3xl border border-artisan-clay bg-white p-5 lg:flex-row lg:items-center lg:justify-between"
                >
                  <div className="flex flex-col gap-3 md:flex-row md:items-start">
                    <div className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-artisan-clay bg-artisan-bone">
                      {thread.shop?.logo_url ? (
                        <div
                          aria-label={`${thread.shop?.name ?? "Shop"} logo`}
                          className="h-full w-full bg-cover bg-center"
                          style={{
                            backgroundImage: `url("${thread.shop.logo_url}")`,
                          }}
                        />
                      ) : (
                        <Store className="h-5 w-5 text-artisan-sienna" />
                      )}
                    </div>
                    <div className="space-y-1">
                      <h3 className="text-lg font-semibold text-artisan-sienna">
                        {thread.shop?.name ?? "Unknown shop"}
                      </h3>
                      <p className="text-xs uppercase tracking-[0.15em] text-artisan-terracotta">
                        Vendor: {thread.vendor?.display_name ?? thread.vendor?.email ?? "Unknown"}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        <span className="font-medium text-artisan-sienna">
                          {lastSender}:{" "}
                        </span>
                        {thread.last_message_preview ??
                          "No messages yet. Say hello."}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatTimestamp(thread.last_message_at ?? thread.created_at)}
                      </p>
                    </div>
                  </div>
                  <Button
                    asChild
                    className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
                  >
                    <Link href={`/admin/shops/${thread.shop_id}/messages`}>
                      Open chat
                      <ArrowRight className="h-4 w-4" />
                    </Link>
                  </Button>
                </div>
              );
            })}
          </div>
        )}
      </PanelCard>
    </>
  );
}
