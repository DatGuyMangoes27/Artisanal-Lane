import Link from "next/link";

import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { listOrders } from "@/lib/admin-data";

function formatCurrency(value: number) {
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
    maximumFractionDigits: 0,
  }).format(value);
}

function formatTimelineDate(value: string | null) {
  return value ? new Date(value).toLocaleDateString() : "—";
}

function readParam(
  value: string | string[] | undefined,
  fallback = "",
) {
  return typeof value === "string" ? value : fallback;
}

export default async function AdminOrdersPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const params = await searchParams;
  const query = readParam(params.query);
  const status = readParam(params.status, "all");
  const shipping = readParam(params.shipping, "all");
  const sort = readParam(params.sort, "newest");
  const orders = await listOrders({ query, status, shipping, sort });

  return (
    <>
      <AdminPageHeader
        eyebrow="Orders"
        title="Marketplace Orders"
        description="Monitor order health, shipping progress, and payout-sensitive states across all shops."
      />

      <PanelCard title="Orders">
        <form className="mb-6 grid gap-3 md:grid-cols-5" method="get">
          <input
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={query}
            name="query"
            placeholder="Search order, buyer, shop"
            type="search"
          />
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={status}
            name="status"
          >
            <option value="all">All statuses</option>
            <option value="pending">Pending</option>
            <option value="paid">Paid</option>
            <option value="shipped">Shipped</option>
            <option value="delivered">Delivered</option>
            <option value="completed">Completed</option>
            <option value="disputed">Disputed</option>
            <option value="cancelled">Cancelled</option>
          </select>
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={shipping}
            name="shipping"
          >
            <option value="all">All shipping methods</option>
            <option value="courier_guy">Courier Guy</option>
            <option value="pargo">Pargo</option>
            <option value="market_pickup">Market pickup</option>
            <option value="unknown">Unknown</option>
          </select>
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={sort}
            name="sort"
          >
            <option value="newest">Newest first</option>
            <option value="oldest">Oldest first</option>
            <option value="total-high">Highest total</option>
            <option value="total-low">Lowest total</option>
            <option value="status">Status A-Z</option>
          </select>
          <div className="flex gap-3">
            <Button className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90" type="submit">
              Apply
            </Button>
            <Button asChild type="button" variant="outline">
              <Link href="/admin/orders">Reset</Link>
            </Button>
          </div>
        </form>

        <div className="overflow-hidden rounded-3xl border border-artisan-clay">
          <div className="overflow-x-auto">
            <table className="min-w-full bg-white text-sm">
              <thead className="bg-artisan-bone/80 text-left text-artisan-sienna">
                <tr>
                  <th className="px-4 py-3 font-semibold">Order</th>
                  <th className="px-4 py-3 font-semibold">Buyer</th>
                  <th className="px-4 py-3 font-semibold">Shop</th>
                  <th className="px-4 py-3 font-semibold">Status</th>
                  <th className="px-4 py-3 font-semibold">Payout</th>
                  <th className="px-4 py-3 font-semibold">Shipping</th>
                  <th className="px-4 py-3 font-semibold">Timeline</th>
                  <th className="px-4 py-3 font-semibold">Total</th>
                </tr>
              </thead>
              <tbody>
                {orders.length === 0 ? (
                  <tr className="border-t border-artisan-clay/70 text-muted-foreground">
                    <td className="px-4 py-8 text-center" colSpan={8}>
                      No orders match the current filters.
                    </td>
                  </tr>
                ) : null}
                {orders.map((order) => (
                  <tr
                    key={order.id}
                    className="border-t border-artisan-clay/70 text-muted-foreground"
                  >
                    <td className="px-4 py-3 font-medium text-artisan-sienna">
                      {order.id.slice(0, 8)}
                    </td>
                    <td className="px-4 py-3">
                      {order.buyer?.display_name ?? "Unknown"}
                    </td>
                    <td className="px-4 py-3">
                      {order.shop?.name ?? "Unknown"}
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge value={order.status} />
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge
                        value={order.payout_profile?.verification_status ?? "not_started"}
                      />
                      {(order.payout_profile?.verification_status ?? "not_started") !==
                      "verified" ? (
                        <div className="mt-1 text-xs">
                          Payout setup incomplete
                        </div>
                      ) : null}
                    </td>
                    <td className="px-4 py-3">
                      <div>{order.shipping_method ?? "Unknown"}</div>
                      {order.tracking_number ? (
                        <div className="text-xs">
                          Tracking: {order.tracking_number}
                        </div>
                      ) : null}
                    </td>
                    <td className="px-4 py-3 text-xs">
                      <div>Ordered: {formatTimelineDate(order.created_at)}</div>
                      <div>Shipped: {formatTimelineDate(order.shipped_at)}</div>
                      <div>Received: {formatTimelineDate(order.received_at)}</div>
                    </td>
                    <td className="px-4 py-3 font-medium text-artisan-sienna">
                      {formatCurrency(order.grand_total)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </PanelCard>
    </>
  );
}
