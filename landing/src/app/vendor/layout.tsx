import { VendorShell } from "@/components/vendor/vendor-shell";
import { getVendorShop, requireVendorSession } from "@/lib/marketplace/vendor-data";

export const dynamic = "force-dynamic";

export default async function VendorLayout({ children }: { children: React.ReactNode }) {
  const session = await requireVendorSession("/vendor");
  const shop = session.isApprovedVendor ? await getVendorShop(session.user.id) : null;

  return <VendorShell shop={shop}>{children}</VendorShell>;
}
