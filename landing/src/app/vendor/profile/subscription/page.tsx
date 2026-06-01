import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { cancelVendorSubscription, startVendorSubscription } from "@/app/vendor/actions";
import { getVendorSubscription, requireVendorSession } from "@/lib/marketplace/vendor-data";
import { formatVendorStatus, isVendorSubscriptionActive } from "@/lib/marketplace/vendor-utils";

export default async function VendorSubscriptionPage() {
  const { user } = await requireVendorSession("/vendor/profile/subscription");
  const subscription = await getVendorSubscription(user.id);
  const active = isVendorSubscriptionActive(subscription);

  return (
    <div>
      <VendorPageHeader
        eyebrow="PayFast"
        title="Subscription"
        description="Start or manage the artisan subscription used by the mobile vendor onboarding flow."
      />
      <VendorPanel title={`Status: ${formatVendorStatus(subscription?.status)}`}>
        <div className="space-y-4 text-sm text-muted-foreground">
          <p>Plan: {subscription?.planCode ?? "artisan-monthly"}</p>
          <p>
            Current period ends:{" "}
            {subscription?.currentPeriodEnd
              ? new Intl.DateTimeFormat("en-ZA", { dateStyle: "medium" }).format(
                  new Date(subscription.currentPeriodEnd),
                )
              : "Not available"}
          </p>
          <p>{active ? "Product creation is enabled by this subscription." : "Start checkout to enable product creation."}</p>
          <div className="flex flex-wrap gap-3">
            <form action={startVendorSubscription}>
              <Button className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
                {active ? "Refresh / restart checkout" : "Start subscription checkout"}
              </Button>
            </form>
            {active ? (
              <form action={cancelVendorSubscription}>
                <Button type="submit" variant="outline">Cancel at PayFast</Button>
              </form>
            ) : null}
          </div>
        </div>
      </VendorPanel>
    </div>
  );
}
