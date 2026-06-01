import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { saveVendorPayoutDetails } from "@/app/vendor/actions";
import { getVendorPayoutProfile, requireVendorSession } from "@/lib/marketplace/vendor-data";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

export default async function VendorPayoutsPage() {
  const { user } = await requireVendorSession("/vendor/profile/payouts");
  const payout = await getVendorPayoutProfile(user.id);

  return (
    <div>
      <VendorPageHeader
        eyebrow="TradeSafe"
        title="Payout details"
        description="Save the bank and identity details needed before products can be sold and escrow can be released."
      />
      <VendorPanel
        title={`Status: ${formatVendorStatus(payout?.verificationStatus)}`}
        description={payout?.statusNotes ?? "Your payout details stay server-side and are used for TradeSafe readiness."}
      >
        <form action={saveVendorPayoutDetails} className="grid gap-4 lg:grid-cols-2">
          <input name="accountHolderName" required defaultValue={payout?.accountHolderName ?? ""} placeholder="Account holder name" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="bankName" required defaultValue={payout?.bankName ?? ""} placeholder="Bank name" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="accountNumber" required defaultValue={payout?.accountNumber ?? ""} placeholder="Account number" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="branchCode" required defaultValue={payout?.branchCode ?? ""} placeholder="Branch code" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="accountType" required defaultValue={payout?.accountType ?? ""} placeholder="Account type" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="registeredPhone" required defaultValue={payout?.registeredPhone ?? ""} placeholder="Registered phone" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="registeredEmail" required type="email" defaultValue={payout?.registeredEmail ?? ""} placeholder="Registered email" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="identityNumber" required defaultValue={payout?.identityNumber ?? ""} placeholder="South African ID number" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm" />
          <input name="businessRegistrationNumber" placeholder="Business registration number (optional)" className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm lg:col-span-2" />
          <Button className="w-fit rounded-full bg-artisan-terracotta px-8 hover:bg-artisan-terracotta/90">
            Save payout details
          </Button>
        </form>
      </VendorPanel>
    </div>
  );
}
