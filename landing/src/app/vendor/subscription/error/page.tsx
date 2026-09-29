import Link from "next/link";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { requireVendorSession } from "@/lib/marketplace/vendor-data";

export default async function VendorSubscriptionErrorPage() {
  await requireVendorSession("/vendor/subscription/error");

  return (
    <div>
      <VendorPageHeader
        eyebrow="PayFast"
        title="Checkout not completed"
        description="No new subscription was activated from this checkout. You can safely try again."
      />
      <VendorPanel title="Return to subscription settings">
        <div className="space-y-5 text-sm text-muted-foreground">
          <p>
            If PayFast shows a completed subscription despite seeing this page, please
            contact Artisan Lane support with the PayFast subscription reference.
          </p>
          <Button asChild className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
            <Link href="/vendor/profile/subscription">Back to subscription</Link>
          </Button>
        </div>
      </VendorPanel>
    </div>
  );
}
