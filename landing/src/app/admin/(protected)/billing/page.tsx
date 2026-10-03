import {
  ApprovedChangesTable,
  CustomChangeForm,
  type BillingRowData,
} from "@/components/admin/billing-changes";
import { AdminPageHeader, PanelCard } from "@/components/admin/admin-ui";
import {
  APPROVED_CHANGES,
  NO_CHANGE_STAY_R349,
} from "@/lib/admin-billing-plan";
import { createAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";

async function loadRows(): Promise<BillingRowData[]> {
  const admin = createAdminClient();
  const emails = APPROVED_CHANGES.map((c) => c.email);

  const { data: profiles } = await admin
    .from("profiles")
    .select("id, email")
    .in("email", emails);
  const idByEmail = new Map<string, string>();
  for (const p of profiles ?? []) {
    if (p.email) idByEmail.set(String(p.email).toLowerCase(), p.id as string);
  }
  const ids = Array.from(idByEmail.values());

  const [{ data: shops }, { data: subs }] = await Promise.all([
    ids.length
      ? admin.from("shops").select("name, vendor_id").in("vendor_id", ids)
      : Promise.resolve({ data: [] }),
    ids.length
      ? admin
          .from("vendor_subscriptions")
          .select("vendor_id, amount, plan_code")
          .in("vendor_id", ids)
      : Promise.resolve({ data: [] }),
  ]);
  const shopByVendor = new Map(
    (shops ?? []).map((s) => [s.vendor_id as string, s.name as string]),
  );
  const subByVendor = new Map(
    (subs ?? []).map((s) => [
      s.vendor_id as string,
      { amount: Number(s.amount), plan_code: s.plan_code as string | null },
    ]),
  );

  return APPROVED_CHANGES.map((change) => {
    const vendorId = idByEmail.get(change.email);
    const sub = vendorId ? subByVendor.get(vendorId) : undefined;
    return {
      email: change.email,
      shopName: vendorId ? (shopByVendor.get(vendorId) ?? null) : null,
      found: Boolean(vendorId),
      rule: change.rule,
      description: change.description,
      localAmount: sub?.amount ?? null,
      localPlanCode: sub?.plan_code ?? null,
    };
  });
}

export default async function AdminBillingPage() {
  const rows = await loadRows();

  return (
    <>
      <AdminPageHeader
        eyebrow="Billing"
        title="Subscription Billing Changes"
        description="Preview and apply approved PayFast subscription changes one shop at a time. Nothing is applied automatically."
      />

      <div className="space-y-6">
        <PanelCard
          title="Approved changes"
          description="Preview shows PayFast's current amount and next charge date, then Apply updates PayFast and our record."
        >
          <ApprovedChangesTable rows={rows} />
        </PanelCard>

        {NO_CHANGE_STAY_R349.length > 0 ? (
          <PanelCard title="No change (stay R349)">
            <ul className="list-disc space-y-1 pl-5 text-sm text-muted-foreground">
              {NO_CHANGE_STAY_R349.map((email) => (
                <li key={email}>{email}</li>
              ))}
            </ul>
          </PanelCard>
        ) : null}

        <PanelCard
          title="Custom change"
          description="Change one shop's amount and/or next charge date. Preview first, then apply."
        >
          <CustomChangeForm />
        </PanelCard>
      </div>
    </>
  );
}
