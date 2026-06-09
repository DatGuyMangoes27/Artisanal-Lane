import Link from "next/link";

import { Button } from "@/components/ui/button";
import { VendorMetric, VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import {
  getVendorDashboardData,
  requireVendorSession,
} from "@/lib/marketplace/vendor-data";
import { formatPrice } from "@/lib/marketplace/format";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

export default async function VendorDashboardPage() {
  const session = await requireVendorSession("/vendor");

  if (!session.isApprovedVendor) {
    return (
      <div>
        <VendorPageHeader
          eyebrow="Artisan Access"
          title="Your artisan application"
          description="This portal opens once your artisan profile is approved. You can check your current application status here."
        />
        <VendorPanel title="Application status">
          {session.application ? (
            <div className="space-y-3 text-sm text-muted-foreground">
              <p>
                <span className="font-medium text-artisan-sienna">
                  {session.application.businessName}
                </span>{" "}
                is currently {formatVendorStatus(session.application.status).toLowerCase()}.
              </p>
              <p>
                Submitted on{" "}
                {new Intl.DateTimeFormat("en-ZA", { dateStyle: "medium" }).format(
                  new Date(session.application.createdAt),
                )}
                .
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              <p className="text-sm text-muted-foreground">
                You haven&apos;t applied to sell on Artisan Lane yet. Tell us about your craft and
                our team will review your application.
              </p>
              <Button asChild className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
                <Link href="/vendor/apply">Start your application</Link>
              </Button>
            </div>
          )}
        </VendorPanel>
      </div>
    );
  }

  const data = await getVendorDashboardData(session.user.id);

  return (
    <div>
      <VendorPageHeader
        eyebrow="Vendor Dashboard"
        title={`Welcome back${data.shop?.name ? `, ${data.shop.name}` : ""}`}
        description="Manage your products, orders, payout readiness, subscription, posts, and customer conversations from one web workspace."
        actions={
          data.setup.canAddProducts ? (
            <Button asChild className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
              <Link href="/vendor/products/new">Add product</Link>
            </Button>
          ) : (
            <Button asChild className="rounded-full" variant="outline">
              <Link
                href={
                  data.setup.missingSteps.includes("Shop profile")
                    ? "/vendor/profile/shop"
                    : data.setup.missingSteps.includes("Payout details")
                      ? "/vendor/profile/payouts"
                      : "/vendor/profile/subscription"
                }
              >
                Complete setup
              </Link>
            </Button>
          )
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <VendorMetric label="Products" value={String(data.productCount)} helper="Active catalog items" />
        <VendorMetric label="Orders" value={String(data.orderCount)} helper="All orders from buyers" />
        <VendorMetric
          label="Active orders"
          value={String(data.activeOrderCount)}
          helper="Needs preparation or follow-up"
        />
        <VendorMetric
          label="Released"
          value={formatPrice(data.earnings.released)}
          helper="Escrow released after fees"
        />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_0.8fr]">
        <VendorPanel title="Setup checklist" description="Product creation stays gated until money setup is complete.">
          <div className="grid gap-3 text-sm">
            {[
              ["Shop profile", !data.setup.missingSteps.includes("Shop profile"), "/vendor/profile/shop"],
              ["Payout details", data.setup.payoutReady, "/vendor/profile/payouts"],
              ["Subscription", data.setup.subscriptionActive, "/vendor/profile/subscription"],
            ].map(([label, complete, href]) => (
              <Link
                key={String(label)}
                href={String(href)}
                className="flex items-center justify-between rounded-2xl border border-artisan-clay/60 bg-artisan-bone/30 px-4 py-3"
              >
                <span className="font-medium text-artisan-sienna">{label}</span>
                <span className={complete ? "text-green-700" : "text-amber-700"}>
                  {complete ? "Complete" : "Needs attention"}
                </span>
              </Link>
            ))}
          </div>
        </VendorPanel>

        <VendorPanel title="Quick status">
          <div className="space-y-3 text-sm text-muted-foreground">
            <p>
              Subscription:{" "}
              <span className="font-medium text-artisan-sienna">
                {formatVendorStatus(data.subscription?.status)}
              </span>
            </p>
            <p>
              Payouts:{" "}
              <span className="font-medium text-artisan-sienna">
                {formatVendorStatus(data.payout?.verificationStatus)}
              </span>
            </p>
            <p>
              Messages needing attention:{" "}
              <span className="font-medium text-artisan-sienna">{data.unreadMessageCount}</span>
            </p>
            <p>
              Shop availability:{" "}
              <span className="font-medium text-artisan-sienna">
                {data.shop?.isOffline ? "Offline/vacation mode" : "Taking orders"}
              </span>
            </p>
          </div>
        </VendorPanel>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <VendorPanel title="Recent orders">
          <div className="space-y-3">
            {data.recentOrders.length === 0 ? (
              <p className="text-sm text-muted-foreground">No orders yet.</p>
            ) : null}
            {data.recentOrders.map((order) => (
              <Link
                key={order.id}
                href={`/vendor/orders/${order.id}`}
                className="flex items-center justify-between rounded-2xl border border-artisan-clay/60 px-4 py-3 text-sm"
              >
                <span className="font-medium text-artisan-sienna">#{order.shortId}</span>
                <span>{formatVendorStatus(order.status)}</span>
                <span>{formatPrice(order.total + order.shippingCost)}</span>
              </Link>
            ))}
          </div>
        </VendorPanel>

        <VendorPanel title="Posts and markets">
          <div className="grid gap-3 text-sm text-muted-foreground">
            <p>{data.posts.length} recent shop posts loaded.</p>
            <p>{data.marketEvents.length} upcoming market events loaded.</p>
            <div className="flex flex-wrap gap-2">
              <Button asChild variant="outline">
                <Link href="/vendor/profile/posts">Manage posts</Link>
              </Button>
              <Button asChild variant="outline">
                <Link href="/vendor/profile/shop">Manage markets</Link>
              </Button>
            </div>
          </div>
        </VendorPanel>
      </div>
    </div>
  );
}
