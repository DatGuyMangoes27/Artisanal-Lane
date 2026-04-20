import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Mailbox } from "lucide-react";

import { AdminChatAutoRefresh } from "@/components/admin/admin-chat-auto-refresh";
import { AdminShopChatPanel } from "@/components/admin/admin-shop-chat";
import { AdminPageHeader, PanelCard } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { requireAdminSession } from "@/lib/admin-auth";
import {
  getAdminShopThreadMessages,
  getOrCreateAdminShopThread,
  getShopForAdminChat,
} from "@/lib/admin-messaging";

export default async function AdminShopMessagesPage({
  params,
}: {
  params: Promise<{ shopId: string }>;
}) {
  const { shopId } = await params;
  const session = await requireAdminSession();

  const [shop, thread] = await Promise.all([
    getShopForAdminChat(shopId),
    getOrCreateAdminShopThread(shopId, session.user.id),
  ]);

  if (!shop || !thread) {
    notFound();
  }

  const messages = await getAdminShopThreadMessages(thread.id);

  const vendorName =
    shop.vendor?.display_name ?? shop.vendor?.email ?? "the shop owner";

  return (
    <>
      <AdminChatAutoRefresh intervalMs={4000} />
      <AdminPageHeader
        eyebrow="Shop Messaging"
        title={`Message ${shop.name}`}
        description={`Send a direct message to ${vendorName}. It appears in their vendor inbox as "Artisan Lane Support".`}
        actions={
          <div className="flex flex-wrap gap-3">
            <Button asChild variant="outline">
              <Link href={`/admin/shops/${shop.id}`}>
                <ArrowLeft className="h-4 w-4" />
                Back to shop
              </Link>
            </Button>
            <Button
              asChild
              className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
            >
              <Link href="/admin/messages">
                <Mailbox className="h-4 w-4" />
                All shop chats
              </Link>
            </Button>
          </div>
        }
      />

      <div className="grid gap-6 xl:grid-cols-[1.4fr_0.6fr]">
        <PanelCard
          title="Conversation"
          description="Messages are stored in the same inbox the shop uses for customer chats."
        >
          <AdminShopChatPanel
            adminUserId={session.user.id}
            messages={messages.map((message) => ({
              id: message.id,
              body: message.body,
              sender_id: message.sender_id,
              created_at: message.created_at,
              attachment_url: message.attachment_url,
              attachment_name: message.attachment_name,
              attachment_mime: message.attachment_mime,
              sender: message.sender
                ? {
                    id: message.sender.id,
                    display_name: message.sender.display_name,
                    email: message.sender.email,
                  }
                : null,
            }))}
            shopId={shop.id}
            shopName={shop.name}
            vendorName={vendorName}
          />
        </PanelCard>

        <PanelCard
          title="Shop context"
          description="Quick snapshot of who you're chatting with."
        >
          <div className="space-y-3 text-sm text-muted-foreground">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-artisan-terracotta">
                Shop
              </p>
              <p className="text-base font-semibold text-artisan-sienna">
                {shop.name}
              </p>
            </div>
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-artisan-terracotta">
                Vendor
              </p>
              <p className="text-base font-semibold text-artisan-sienna">
                {shop.vendor?.display_name ?? "Unknown"}
              </p>
              <p className="text-sm text-muted-foreground">
                {shop.vendor?.email ?? "No email on file"}
              </p>
            </div>
            {shop.location ? (
              <div>
                <p className="text-xs uppercase tracking-[0.2em] text-artisan-terracotta">
                  Location
                </p>
                <p className="text-sm text-artisan-sienna">{shop.location}</p>
              </div>
            ) : null}
            <div className="rounded-2xl border border-artisan-clay bg-artisan-bone/40 p-4 text-xs leading-relaxed text-artisan-sienna">
              Messages you send here use the same infrastructure as
              buyer&nbsp;&rarr;&nbsp;vendor chat. The shop owner will see the
              conversation in <strong>Vendor &rarr; Messages</strong> with an
              &quot;Artisan Lane Support&quot; badge.
            </div>
          </div>
        </PanelCard>
      </div>
    </>
  );
}
