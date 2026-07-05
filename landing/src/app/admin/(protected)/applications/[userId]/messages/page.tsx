import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { AdminChatAutoRefresh } from "@/components/admin/admin-chat-auto-refresh";
import { AdminApplicantChatPanel } from "@/components/admin/admin-shop-chat";
import { AdminPageHeader, PanelCard } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { requireAdminSession } from "@/lib/admin-auth";
import {
  getAdminShopThreadMessages,
  getOrCreateAdminApplicantThread,
  markAdminApplicantThreadRead,
} from "@/lib/admin-messaging";
import { createAdminClient } from "@/lib/supabase/admin";

export default async function AdminApplicantMessagesPage({
  params,
}: {
  params: Promise<{ userId: string }>;
}) {
  const { userId } = await params;
  const session = await requireAdminSession();

  const admin = createAdminClient();
  const [{ data: profile }, thread] = await Promise.all([
    admin
      .from("profiles")
      .select("id, display_name, email")
      .eq("id", userId)
      .maybeSingle(),
    getOrCreateAdminApplicantThread(userId, session.user.id),
  ]);

  if (!profile || !thread) {
    notFound();
  }

  const applicantName =
    (profile.display_name as string | null) ??
    (profile.email as string | null) ??
    "the applicant";

  const messages = await getAdminShopThreadMessages(thread.id);
  await markAdminApplicantThreadRead(thread.id);

  return (
    <>
      <AdminChatAutoRefresh intervalMs={4000} />
      <AdminPageHeader
        eyebrow="Vendor Applications"
        title={`Message ${applicantName}`}
        description="Ask for more information before approving or declining the application. The applicant sees this conversation in their Artisan Lane inbox."
        actions={
          <Button asChild variant="outline">
            <Link href="/admin/applications">
              <ArrowLeft className="h-4 w-4" />
              Back to applications
            </Link>
          </Button>
        }
      />

      <PanelCard
        title="Conversation"
        description="Messages are delivered to the applicant's account inbox with a push notification."
      >
        <AdminApplicantChatPanel
          adminUserId={session.user.id}
          applicantUserId={userId}
          applicantName={applicantName}
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
        />
      </PanelCard>
    </>
  );
}
