import Link from "next/link";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { VendorSubscriptionReturnStatus } from "@/components/vendor/vendor-subscription-return-status";
import { getVendorSubscription, requireVendorSession } from "@/lib/marketplace/vendor-data";
import { isVendorSubscriptionActive } from "@/lib/marketplace/vendor-utils";

export default async function VendorSubscriptionSuccessPage() {
  const { user } = await requireVendorSession("/vendor/subscription/success");
  const subscription = await getVendorSubscription(user.id);
  const active = isVendorSubscriptionActive(subscription);

  return (
    <div>
      <VendorPageHeader
        eyebrow="PayFast"
        title={active ? "Subscription active" : "Payment details received"}
        description="Thank you. We are matching PayFast's confirmation to your Artisan Lane account."
      />
      <VendorPanel title={active ? "You are all set" : "Confirmation in progress"}>
        <div className="space-y-5 text-sm text-muted-foreground">
          <VendorSubscriptionReturnStatus active={active} />
          {active && subscription?.currentPeriodEnd ? (
            <p>
              Your current access period runs until{" "}
              <strong className="text-artisan-sienna">
                {new Intl.DateTimeFormat("en-ZA", { dateStyle: "long" }).format(
                  new Date(subscription.currentPeriodEnd),
                )}
              </strong>
              .
            </p>
          ) : null}
          <div className="flex flex-wrap gap-3">
            <Button asChild className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
              <Link href={active ? "/vendor" : "/vendor/profile/subscription"}>
                {active ? "Continue to vendor portal" : "View subscription status"}
              </Link>
            </Button>
            <Button asChild variant="outline" className="rounded-full">
              <Link href="/">Return to Artisan Lane</Link>
            </Button>
          </div>
        </div>
      </VendorPanel>
    </div>
  );
}
