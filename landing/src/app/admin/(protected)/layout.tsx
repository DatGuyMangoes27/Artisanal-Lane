import { AdminLiveRefresh } from "@/components/admin/admin-live-refresh";
import { AdminShell } from "@/components/admin/admin-shell";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { requireAdminSession } from "@/lib/admin-auth";
import { countUnreadAdminShopThreads } from "@/lib/admin-messaging";

export default async function AdminProtectedLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const session = await requireAdminSession();
  const unreadMessageCount = await countUnreadAdminShopThreads();

  return (
    <>
      <AdminLiveRefresh />
      <MarketplaceHeader />
      <AdminShell
        displayName={session.profile.display_name ?? "Admin"}
        email={session.profile.email ?? session.user.email ?? "Unknown"}
        unreadMessageCount={unreadMessageCount}
      >
        {children}
      </AdminShell>
    </>
  );
}
