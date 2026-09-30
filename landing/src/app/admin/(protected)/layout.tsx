import { AdminLiveRefresh } from "@/components/admin/admin-live-refresh";
import { AdminShell } from "@/components/admin/admin-shell";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { requireAdminSession } from "@/lib/admin-auth";
import { countUnreadAdminShopThreads } from "@/lib/admin-messaging";
import { countOpenModerationReports } from "@/lib/admin-moderation-data";

export default async function AdminProtectedLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const session = await requireAdminSession();
  const [unreadMessageCount, openReportCount] = await Promise.all([
    countUnreadAdminShopThreads(),
    countOpenModerationReports(),
  ]);

  return (
    <>
      <AdminLiveRefresh />
      <MarketplaceHeader />
      <AdminShell
        displayName={session.profile.display_name ?? "Admin"}
        email={session.profile.email ?? session.user.email ?? "Unknown"}
        unreadMessageCount={unreadMessageCount}
        openReportCount={openReportCount}
      >
        {children}
      </AdminShell>
    </>
  );
}
