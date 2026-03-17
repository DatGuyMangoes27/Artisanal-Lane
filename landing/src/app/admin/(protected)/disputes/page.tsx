import { CheckCircle2, Undo2 } from "lucide-react";

import {
  resolveDisputeRefund,
  resolveDisputeRelease,
} from "@/app/admin/actions";
import { DisputeResolutionForm } from "@/components/admin/dispute-resolution-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { listDisputes } from "@/lib/admin-data";

export default async function AdminDisputesPage() {
  const disputes = await listDisputes();

  return (
    <>
      <AdminPageHeader
        eyebrow="Disputes"
        title="Resolve Escrow Issues"
        description="Record a written resolution and either release funds or mark the transaction as refunded."
      />

      <PanelCard title="Disputes Queue">
        <div className="space-y-4">
          {disputes.map((dispute) => (
            <div
              key={dispute.id}
              className="rounded-3xl border border-artisan-clay bg-white p-5"
            >
              <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-xl font-semibold text-artisan-sienna">
                      {dispute.shop?.name ?? "Unknown shop"}
                    </h3>
                    <StatusBadge value={dispute.status} />
                  </div>
                  <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-2">
                    <p>
                      <span className="font-medium text-artisan-sienna">Raised by:</span>{" "}
                      {dispute.raisedByProfile?.display_name ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Order:</span>{" "}
                      {dispute.order_id.slice(0, 8)}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Order status:</span>{" "}
                      {dispute.order?.status ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Opened:</span>{" "}
                      {new Date(dispute.created_at).toLocaleDateString()}
                    </p>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    <span className="font-medium text-artisan-sienna">Reason:</span>{" "}
                    {dispute.reason}
                  </p>
                  {dispute.resolution ? (
                    <p className="text-sm text-muted-foreground">
                      <span className="font-medium text-artisan-sienna">Resolution:</span>{" "}
                      {dispute.resolution}
                    </p>
                  ) : null}
                </div>

                {dispute.status === "open" || dispute.status === "investigating" ? (
                  <div className="w-full max-w-xl space-y-3">
                    <DisputeResolutionForm
                      action={resolveDisputeRelease}
                      buttonClassName="bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                      disputeId={dispute.id}
                      idleContent={
                        <>
                          <CheckCircle2 className="mr-2 h-4 w-4" />
                          Release Funds
                        </>
                      }
                      orderId={dispute.order_id}
                      pendingLabel="Releasing..."
                      placeholder="Explain why funds should be released to the seller..."
                    />

                    <DisputeResolutionForm
                      action={resolveDisputeRefund}
                      buttonClassName="bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                      disputeId={dispute.id}
                      idleContent={
                        <>
                          <Undo2 className="mr-2 h-4 w-4" />
                          Refund Buyer
                        </>
                      }
                      orderId={dispute.order_id}
                      pendingLabel="Refunding..."
                      placeholder="Explain why the buyer should be refunded..."
                    />
                  </div>
                ) : null}
              </div>
            </div>
          ))}
        </div>
      </PanelCard>
    </>
  );
}
