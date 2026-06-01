import Link from "next/link";

import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { listVendorChatThreads, requireVendorSession } from "@/lib/marketplace/vendor-data";

export default async function VendorMessagesPage() {
  const { user } = await requireVendorSession("/vendor/messages");
  const threads = await listVendorChatThreads(user.id);

  return (
    <div>
      <VendorPageHeader
        eyebrow="Community"
        title="Messages"
        description="Reply to buyer conversations from your shop profile and product pages."
      />
      <VendorPanel title="Inbox">
        {threads.length === 0 ? (
          <p className="text-sm text-muted-foreground">No buyer conversations yet.</p>
        ) : null}
        <div className="grid gap-3">
          {threads.map((thread) => {
            const unread =
              thread.lastMessageAt &&
              thread.lastMessageSenderId !== user.id &&
              (!thread.lastReadAt || new Date(thread.lastMessageAt) > new Date(thread.lastReadAt));
            return (
              <Link
                key={thread.id}
                href={`/vendor/messages/${thread.id}`}
                className="rounded-3xl border border-artisan-clay/70 p-4 text-sm transition hover:bg-artisan-bone/40"
              >
                <div className="flex items-center justify-between gap-3">
                  <p className="font-semibold text-artisan-sienna">
                    {thread.buyerName ?? thread.buyerEmail ?? "Buyer"}
                  </p>
                  {unread ? <span className="text-amber-700">Unread</span> : null}
                </div>
                <p className="mt-2 text-muted-foreground">
                  {thread.lastMessagePreview ?? "Start the conversation"}
                </p>
              </Link>
            );
          })}
        </div>
      </VendorPanel>
    </div>
  );
}
