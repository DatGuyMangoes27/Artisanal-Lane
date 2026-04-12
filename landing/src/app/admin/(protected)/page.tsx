import { Clock3, PackageOpen, ShieldAlert, Store, Users } from "lucide-react";

import { AdminPageHeader, MetricCard, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import {
  getDashboardStats,
  listDisputes,
  listOrders,
  listStationeryRequests,
  listVendorApplications,
} from "@/lib/admin-data";

function formatCurrency(value: number) {
  return new Intl.NumberFormat("en-ZA", {
    style: "currency",
    currency: "ZAR",
    maximumFractionDigits: 0,
  }).format(value);
}

export default async function AdminDashboardPage() {
  const [stats, applications, orders, disputes, stationeryRequests] = await Promise.all([
    getDashboardStats(),
    listVendorApplications(),
    listOrders(),
    listDisputes(),
    listStationeryRequests(),
  ]);

  const pendingApplications = applications.filter(
    (application) => application.status === "pending",
  );
  const openDisputes = disputes.filter(
    (dispute) => dispute.status === "open" || dispute.status === "investigating",
  );
  const openStationeryRequests = stationeryRequests.filter(
    (request) => request.status === "pending" || request.status === "processing",
  );

  return (
    <>
      <AdminPageHeader
        eyebrow="Overview"
        title="Marketplace Control Room"
        description="Track approvals, orders, disputes, and revenue in one place."
      />

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          helper="All marketplace orders"
          label="Orders"
          value={String(stats.ordersCount)}
        />
        <MetricCard
          helper="Applications waiting on review"
          label="Pending Applications"
          value={String(stats.pendingApplications)}
        />
        <MetricCard
          helper="Currently active artisan shops"
          label="Active Shops"
          value={String(stats.activeShops)}
        />
        <MetricCard
          helper="Stationery requests waiting on fulfilment"
          label="Stationery Queue"
          value={String(stats.pendingStationeryRequests)}
        />
      </section>

      <section className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_1fr]">
        <PanelCard
          description="The newest vendor applications that still need an admin decision."
          title="Review Queue"
        >
          <div className="space-y-3">
            {pendingApplications.slice(0, 5).map((application) => (
              <div
                key={application.id}
                className="flex flex-col gap-3 rounded-2xl border border-artisan-clay bg-artisan-bone/40 p-4 md:flex-row md:items-center md:justify-between"
              >
                <div>
                  <p className="font-medium text-artisan-sienna">
                    {application.business_name}
                  </p>
                  <p className="text-sm text-muted-foreground">
                    {application.applicant?.display_name ?? "Unknown applicant"}
                    {" · "}
                    {application.location ?? "Location not provided"}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <StatusBadge value={application.status} />
                  <span className="text-xs text-muted-foreground">
                    <Clock3 className="mr-1 inline h-3.5 w-3.5" />
                    {new Date(application.created_at).toLocaleDateString()}
                  </span>
                </div>
              </div>
            ))}
            {pendingApplications.length === 0 ? (
              <p className="rounded-2xl border border-artisan-clay bg-artisan-bone/40 p-4 text-sm text-muted-foreground">
                No applications are waiting for review.
              </p>
            ) : null}
          </div>
        </PanelCard>

        <PanelCard
          description="Open disputes that may block payouts and customer trust."
          title="Disputes"
        >
          <div className="space-y-3">
            {openDisputes.slice(0, 5).map((dispute) => (
              <div
                key={dispute.id}
                className="rounded-2xl border border-artisan-clay bg-white p-4"
              >
                <div className="flex items-center justify-between gap-3">
                  <p className="font-medium text-artisan-sienna">
                    {dispute.shop?.name ?? "Unknown shop"}
                  </p>
                  <StatusBadge value={dispute.status} />
                </div>
                <p className="mt-2 line-clamp-2 text-sm text-muted-foreground">
                  {dispute.reason}
                </p>
              </div>
            ))}
            {openDisputes.length === 0 ? (
              <p className="rounded-2xl border border-artisan-clay bg-artisan-bone/40 p-4 text-sm text-muted-foreground">
                No disputes are currently open.
              </p>
            ) : null}
          </div>
        </PanelCard>
      </section>

      <section className="mt-6 grid gap-6 xl:grid-cols-2">
        <PanelCard
          description="Recent orders across the marketplace."
          title="Latest Orders"
        >
          <div className="space-y-3">
            {orders.slice(0, 6).map((order) => (
              <div
                key={order.id}
                className="flex flex-col gap-3 rounded-2xl border border-artisan-clay bg-white p-4 md:flex-row md:items-center md:justify-between"
              >
                <div className="flex-1">
                  <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                    <div>
                      <p className="font-medium text-artisan-sienna">
                        {order.shop?.name ?? "Unknown shop"}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        Buyer: {order.buyer?.display_name ?? "Unknown"}
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <StatusBadge value={order.status} />
                      <StatusBadge
                        value={order.payout_profile?.verification_status ?? "not_started"}
                      />
                      <span className="text-sm font-medium text-artisan-sienna">
                        {formatCurrency(order.grand_total)}
                      </span>
                    </div>
                  </div>
                  {(order.payout_profile?.verification_status ?? "not_started") !==
                  "verified" ? (
                    <p className="mt-2 text-xs text-muted-foreground">
                      Vendor payout setup still needs attention before funds can settle
                      cleanly.
                    </p>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        </PanelCard>

        <PanelCard
          description="The newest branded stationery requests from artisan shops."
          title="Stationery Requests"
        >
          <div className="space-y-3">
            {openStationeryRequests.slice(0, 6).map((request) => (
              <div
                key={request.id}
                className="flex flex-col gap-3 rounded-2xl border border-artisan-clay bg-white p-4 md:flex-row md:items-center md:justify-between"
              >
                <div>
                  <p className="font-medium text-artisan-sienna">
                    {request.shop?.name ?? "Unknown shop"}
                  </p>
                  <p className="text-sm text-muted-foreground">
                    {request.totalQuantity} items for{" "}
                    {request.vendor?.display_name ?? request.vendor?.email ?? "Unknown vendor"}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <StatusBadge value={request.status} />
                  <span className="text-xs text-muted-foreground">
                    <Clock3 className="mr-1 inline h-3.5 w-3.5" />
                    {new Date(request.created_at).toLocaleDateString()}
                  </span>
                </div>
              </div>
            ))}
            {openStationeryRequests.length === 0 ? (
              <p className="rounded-2xl border border-artisan-clay bg-artisan-bone/40 p-4 text-sm text-muted-foreground">
                No stationery requests are waiting right now.
              </p>
            ) : null}
          </div>
        </PanelCard>

        <PanelCard
          description="Quick operational focus areas."
          title="Today"
        >
          <div className="grid gap-3 md:grid-cols-2">
            <div className="rounded-2xl border border-artisan-clay bg-artisan-bone/50 p-4">
              <Users className="h-5 w-5 text-artisan-terracotta" />
              <p className="mt-3 font-medium text-artisan-sienna">
                {stats.pendingApplications} applications waiting
              </p>
              <p className="mt-1 text-sm text-muted-foreground">
                Prioritize approvals so sellers can start listing products.
              </p>
            </div>
            <div className="rounded-2xl border border-artisan-clay bg-artisan-bone/50 p-4">
              <ShieldAlert className="h-5 w-5 text-artisan-terracotta" />
              <p className="mt-3 font-medium text-artisan-sienna">
                {stats.openDisputes} open disputes
              </p>
              <p className="mt-1 text-sm text-muted-foreground">
                Resolve blocked payouts before they delay trust and fulfilment.
              </p>
            </div>
            <div className="rounded-2xl border border-artisan-clay bg-artisan-bone/50 p-4">
              <Store className="h-5 w-5 text-artisan-terracotta" />
              <p className="mt-3 font-medium text-artisan-sienna">
                {stats.activeShops} shops are live
              </p>
              <p className="mt-1 text-sm text-muted-foreground">
                Use moderation pages to keep catalogue quality high.
              </p>
            </div>
            <div className="rounded-2xl border border-artisan-clay bg-artisan-bone/50 p-4">
              <PackageOpen className="h-5 w-5 text-artisan-terracotta" />
              <p className="mt-3 font-medium text-artisan-sienna">
                {stats.pendingStationeryRequests} stationery requests active
              </p>
              <p className="mt-1 text-sm text-muted-foreground">
                Pack and dispatch Artisan Lane materials so vendors can fulfil consistently.
              </p>
            </div>
          </div>
        </PanelCard>
      </section>
    </>
  );
}
