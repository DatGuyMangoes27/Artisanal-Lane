import Link from "next/link";

import {
  VendorMetric,
  VendorPageHeader,
  VendorPanel,
  VendorSetupRequired,
} from "@/components/vendor/vendor-shell";
import { getVendorEarnings, getVendorShop, requireVendorSession } from "@/lib/marketplace/vendor-data";
import { formatPrice } from "@/lib/marketplace/format";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

export default async function VendorEarningsPage() {
  const { user } = await requireVendorSession("/vendor/earnings");
  const shop = await getVendorShop(user.id);

  if (!shop) {
    return (
      <div>
        <VendorPageHeader
          eyebrow="Earnings"
          title="Sales and escrow"
          description="Your escrow, fees, and payout totals will appear here once your shop starts receiving orders."
        />
        <VendorSetupRequired title="Create your shop before tracking earnings" />
      </div>
    );
  }

  const earnings = await getVendorEarnings(shop.id);

  return (
    <div>
      <VendorPageHeader
        eyebrow="Earnings"
        title="Sales and escrow"
        description="Track total sales, held escrow, released payouts, platform fees, and recent completed orders."
      />
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <VendorMetric label="Total sales" value={formatPrice(earnings.totalSales)} helper="Escrow transactions counted for vendor earnings" />
        <VendorMetric label="Held" value={formatPrice(earnings.held)} helper="Still protected by escrow" />
        <VendorMetric label="Released" value={formatPrice(earnings.released)} helper="Released after platform fees" />
        <VendorMetric label="Fees" value={formatPrice(earnings.fees)} helper="Platform fees recorded" />
      </div>
      <div className="mt-6">
        <VendorPanel title="Recent earning orders">
          <div className="grid gap-3">
            {earnings.recentOrders.length === 0 ? (
              <p className="text-sm text-muted-foreground">No paid orders yet.</p>
            ) : null}
            {earnings.recentOrders.map((order) => (
              <Link key={order.id} href={`/vendor/orders/${order.id}`} className="flex items-center justify-between rounded-2xl border border-artisan-clay/70 p-4 text-sm">
                <span className="font-medium text-artisan-sienna">#{order.shortId}</span>
                <span>{formatVendorStatus(order.status)}</span>
                <span>{formatPrice(order.total + order.shippingCost)}</span>
              </Link>
            ))}
          </div>
        </VendorPanel>
      </div>
    </div>
  );
}
