import Link from "next/link";

import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import {
  listVendorChatThreads,
  requireVendorSession,
  type VendorChatThread,
} from "@/lib/marketplace/vendor-data";

function ThreadLink({ thread, userId }: { thread: VendorChatThread; userId: string }) {
  const unread =
    thread.lastMessageAt &&
    thread.lastMessageSenderId !== userId &&
    (!thread.lastReadAt || new Date(thread.lastMessageAt) > new Date(thread.lastReadAt));
  return (
    <Link
      href={`/vendor/messages/${thread.id}`}
      className="rounded-3xl border border-artisan-clay/70 p-4 text-sm transition hover:bg-artisan-bone/40"
    >
      <div className="flex items-center justify-between gap-3">
        <p className="font-semibold text-artisan-sienna">
          {thread.isAdminThread
            ? "Artisan Lane Support"
            : thread.buyerName ?? thread.buyerEmail ?? "Buyer"}
        </p>
        {unread ? <span className="text-amber-700">Unread</span> : null}
      </div>
      <p className="mt-2 text-muted-foreground">
        {thread.lastMessagePreview ?? "Start the conversation"}
      </p>
    </Link>
  );
}

export default async function VendorMessagesPage() {
  const { user } = await requireVendorSession("/vendor/messages");
  const threads = await listVendorChatThreads(user.id);
  const adminThreads = threads.filter((thread) => thread.isAdminThread);
  const customerThreads = threads.filter((thread) => !thread.isAdminThread);

  return (
    <div>
      <VendorPageHeader
        eyebrow="Community"
        title="Messages"
        description="Reply to buyer conversations from your shop profile and product pages."
      />
      {adminThreads.length > 0 ? (
        <VendorPanel title="Artisan Lane">
          <div className="grid gap-3">
            {adminThreads.map((thread) => (
              <ThreadLink key={thread.id} thread={thread} userId={user.id} />
            ))}
          </div>
        </VendorPanel>
      ) : null}
      <VendorPanel title={adminThreads.length > 0 ? "Customers" : "Inbox"}>
        {customerThreads.length === 0 ? (
          <p className="text-sm text-muted-foreground">No buyer conversations yet.</p>
        ) : null}
        <div className="grid gap-3">
          {customerThreads.map((thread) => (
            <ThreadLink key={thread.id} thread={thread} userId={user.id} />
          ))}
        </div>
      </VendorPanel>
    </div>
  );
}
