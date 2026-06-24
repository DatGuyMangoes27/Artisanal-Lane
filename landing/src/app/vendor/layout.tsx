import { VendorShell } from "@/components/vendor/vendor-shell";
import {
  getVendorShop,
  getVendorSubscription,
  requireVendorSession,
} from "@/lib/marketplace/vendor-data";
import { isVendorSubscriptionActive } from "@/lib/marketplace/vendor-utils";

export const dynamic = "force-dynamic";

export default async function VendorLayout({ children }: { children: React.ReactNode }) {
  const session = await requireVendorSession("/vendor");
  const shop = session.isApprovedVendor ? await getVendorShop(session.user.id) : null;

  // Approved vendors (not admins) must keep an active subscription to manage
  // products. When inactive, a non-dismissable gate blocks the portal.
  const isVendorRole = session.profile.role === "vendor";
  const subscription = isVendorRole ? await getVendorSubscription(session.user.id) : null;
  const requiresSubscription = isVendorRole && !isVendorSubscriptionActive(subscription);

  return (
    <VendorShell shop={shop} requiresSubscription={requiresSubscription}>
      {children}
    </VendorShell>
  );
}
