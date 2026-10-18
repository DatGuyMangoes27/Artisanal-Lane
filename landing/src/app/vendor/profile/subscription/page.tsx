import Link from "next/link";
import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { cancelVendorSubscription, startVendorSubscription, updateVendorSubscriptionCard } from "@/app/vendor/actions";
import { getVendorSubscription, requireVendorSession } from "@/lib/marketplace/vendor-data";
import {
  formatVendorStatus,
  hasVendorSubscriptionPaymentIssue,
  isVendorSubscriptionActive,
} from "@/lib/marketplace/vendor-utils";

export default async function VendorSubscriptionPage() {
  const { user } = await requireVendorSession("/vendor/profile/subscription");
  const subscription = await getVendorSubscription(user.id);
  const active = isVendorSubscriptionActive(subscription);
  // A failed renewal is fixed by updating the card on the existing PayFast
  // subscription; starting a new one would leave two subscriptions running.
  const paymentIssue = hasVendorSubscriptionPaymentIssue(subscription);
  const displayStatus = paymentIssue
    ? "Payment due"
    : subscription?.status?.toLowerCase() === "active" && !active
      ? "Expired"
      : formatVendorStatus(subscription?.status);

  return (
    <div>
      <VendorPageHeader
        eyebrow="PayFast"
        title="Subscription"
        description="Start or manage the artisan subscription that enables your website shop tools."
      />
      <p className="mb-5 text-sm text-muted-foreground">Your Artisan Lane subscription is separate from payment-provider charges. <Link className="font-semibold underline" href="/terms#artisans">Read the artisan subscription and payout terms</Link>.</p>
      <VendorPanel title={`Status: ${displayStatus}`}>
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
          {paymentIssue ? (
            <p className="rounded-2xl border border-amber-300 bg-amber-50 p-4 text-amber-900">
              Your latest payment didn&apos;t go through. Update your payment card below and
              PayFast will try again. There&apos;s no need to subscribe again. After you update
              your card, the retry can take up to a day; this page updates once the payment goes
              through.
            </p>
          ) : (
            <p>{active ? "Product creation is enabled by this subscription." : "Start checkout to enable product creation."}</p>
          )}
          <div className="flex flex-wrap gap-3">
            {active || paymentIssue ? (
              <form action={updateVendorSubscriptionCard}>
                <Button className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
                  Update payment card
                </Button>
              </form>
            ) : (
              <form action={startVendorSubscription}>
                <Button className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
                  Start subscription checkout
                </Button>
              </form>
            )}
            {active || paymentIssue ? (
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
