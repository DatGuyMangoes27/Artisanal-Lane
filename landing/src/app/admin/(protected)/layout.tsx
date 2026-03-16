import { AdminLiveRefresh } from "@/components/admin/admin-live-refresh";
import { AdminShell } from "@/components/admin/admin-shell";
import { requireAdminSession } from "@/lib/admin-auth";

export default async function AdminProtectedLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const session = await requireAdminSession();

  return (
    <>
      <AdminLiveRefresh />
      <AdminShell
        displayName={session.profile.display_name ?? "Admin"}
        email={session.profile.email ?? session.user.email ?? "Unknown"}
      >
        {children}
      </AdminShell>
    </>
  );
}
