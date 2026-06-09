import { redirect } from "next/navigation";

import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { VendorApplicationForm } from "@/components/vendor/vendor-application-form";
import { requireVendorSession } from "@/lib/marketplace/vendor-data";

export default async function VendorApplyPage() {
  const session = await requireVendorSession("/vendor/apply");

  // Approved artisans (and admins) already have portal access.
  if (session.isApprovedVendor) {
    redirect("/vendor");
  }

  // An application is already in flight — show its status on the dashboard.
  if (session.application) {
    redirect("/vendor");
  }

  return (
    <div>
      <VendorPageHeader
        eyebrow="Artisan Access"
        title="Apply to sell on Artisan Lane"
        description="Tell us about your craft. Our team reviews every application, and your vendor portal unlocks once you're approved."
      />
      <VendorPanel
        title="Your application"
        description="All fields except your business name are optional, but more detail helps us review faster."
      >
        <VendorApplicationForm
          defaultEmail={session.profile.email}
          defaultName={session.profile.displayName}
        />
      </VendorPanel>
    </div>
  );
}
