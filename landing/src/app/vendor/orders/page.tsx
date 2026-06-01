import Link from "next/link";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel, VendorSetupRequired } from "@/components/vendor/vendor-shell";
import { getVendorShop, listVendorOrders, requireVendorSession } from "@/lib/marketplace/vendor-data";
import { formatPrice } from "@/lib/marketplace/format";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

const statusTabs = ["all", "pending", "paid", "shipped", "delivered", "completed", "disputed"];

export default async function VendorOrdersPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  const params = await searchParams;
  const status = params?.status ?? "all";
  const { user } = await requireVendorSession("/vendor/orders");
  const shop = await getVendorShop(user.id);
  if (!shop) {
    return (
      <div>
        <VendorPageHeader
          eyebrow="Fulfilment"
          title="Orders"
          description="Orders will appear here once your shop profile is complete and buyers start checking out."
        />
        <VendorSetupRequired title="Create your shop before receiving orders" />
      </div>
    );
  }

  const orders = await listVendorOrders(shop.id, { status });

  return (
    <div>
      <VendorPageHeader
        eyebrow="Fulfilment"
        title="Orders"
        description="Review buyer details, gifts, shipping/pickup information, escrow state, and mark paid orders as shipped."
      />
      <VendorPanel title="Order queue">
        <div className="mb-5 flex flex-wrap gap-2">
          {statusTabs.map((tab) => (
            <Button key={tab} asChild variant={status === tab ? "default" : "outline"}>
              <Link href={tab === "all" ? "/vendor/orders" : `/vendor/orders?status=${tab}`}>
                {formatVendorStatus(tab)}
              </Link>
            </Button>
          ))}
        </div>
        {orders.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-artisan-clay p-8 text-sm text-muted-foreground">
            No orders match this filter.
          </div>
        ) : null}
        <div className="grid gap-3">
          {orders.map((order) => (
            <Link
              key={order.id}
              href={`/vendor/orders/${order.id}`}
              className="grid gap-3 rounded-3xl border border-artisan-clay/70 p-4 text-sm transition hover:bg-artisan-bone/40 md:grid-cols-[1fr_auto_auto]"
            >
              <div>
                <p className="text-lg font-semibold text-artisan-sienna">Order #{order.shortId}</p>
                <p className="text-muted-foreground">
                  {order.buyerName ?? order.buyerEmail ?? "Buyer"} ·{" "}
                  {new Intl.DateTimeFormat("en-ZA", { dateStyle: "medium" }).format(
                    new Date(order.createdAt),
                  )}
                </p>
              </div>
              <span className="font-medium text-artisan-sienna">
                {formatPrice(order.total + order.shippingCost)}
              </span>
              <span>{formatVendorStatus(order.status)}</span>
            </Link>
          ))}
        </div>
      </VendorPanel>
    </div>
  );
}
