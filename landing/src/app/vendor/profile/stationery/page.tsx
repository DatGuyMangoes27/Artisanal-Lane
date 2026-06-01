import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel, VendorSetupRequired } from "@/components/vendor/vendor-shell";
import { VendorStationeryRequestForm } from "@/components/vendor/vendor-stationery-request-form";
import { payExistingStationeryRequest } from "@/app/vendor/actions";
import Link from "next/link";
import {
  getVendorShop,
  listVendorStationeryRequests,
  requireVendorSession,
} from "@/lib/marketplace/vendor-data";
import { formatPrice } from "@/lib/marketplace/format";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

const statusTabs = ["all", "active", "shipped", "delivered", "cancelled"] as const;

function requestIsActive(status: string) {
  return ["awaiting_payment", "paid", "processing"].includes(status);
}

export default async function VendorStationeryPage({
  searchParams,
}: {
  searchParams?: Promise<{ status?: string }>;
}) {
  const params = await searchParams;
  const { user } = await requireVendorSession("/vendor/profile/stationery");
  const shop = await getVendorShop(user.id);
  const requests = await listVendorStationeryRequests(user.id);
  const selectedStatus = statusTabs.includes(params?.status as (typeof statusTabs)[number])
    ? (params?.status as (typeof statusTabs)[number])
    : "all";
  const filteredRequests = requests.filter((request) => {
    if (selectedStatus === "all") return true;
    if (selectedStatus === "active") return requestIsActive(request.status);
    return request.status === selectedStatus;
  });

  return (
    <div>
      <VendorPageHeader
        eyebrow="Branded Stationery"
        title="Stationery requests"
        description="Request branded packaging inserts and pay through the existing PayFast stationery checkout flow."
      />
      {!shop ? (
        <div className="mb-6">
          <VendorSetupRequired title="Create your shop before ordering stationery" />
        </div>
      ) : null}
      <div className="grid gap-6 xl:grid-cols-[1fr_0.8fr]">
        <VendorPanel
          title="Request history"
          description="Track branded packaging payments, fulfilment, and delivery updates."
        >
          {requests.length === 0 ? (
            <div className="flex min-h-72 flex-col items-center justify-center rounded-3xl border border-dashed border-artisan-clay bg-artisan-bone/30 p-8 text-center">
              <p className="text-lg font-semibold text-artisan-sienna">No stationery requests</p>
              <p className="mt-2 max-w-sm text-sm text-muted-foreground">
                Your paid, processing, shipped, and delivered packaging requests will appear here.
              </p>
            </div>
          ) : (
            <div className="space-y-5">
              <div className="flex flex-wrap gap-2">
                {statusTabs.map((status) => (
                  <Button
                    key={status}
                    asChild
                    size="sm"
                    variant={status === selectedStatus ? "default" : "outline"}
                  >
                    <Link
                      href={
                        status === "all"
                          ? "/vendor/profile/stationery"
                          : `/vendor/profile/stationery?status=${status}`
                      }
                    >
                      {formatVendorStatus(status)}
                    </Link>
                  </Button>
                ))}
              </div>
              {filteredRequests.length === 0 ? (
                <p className="rounded-2xl bg-artisan-bone/35 px-4 py-3 text-sm text-muted-foreground">
                  No requests match this filter.
                </p>
              ) : (
                <div className="space-y-3">
                      {filteredRequests.map((request) => (
                        <div
                          key={request.id}
                          className="rounded-3xl border border-artisan-clay/70 p-4 text-sm"
                        >
                          <div className="flex flex-wrap items-start justify-between gap-3">
                            <div>
                              <p className="font-semibold text-artisan-sienna">
                                Request #{request.id.slice(0, 8).toUpperCase()}
                              </p>
                              <p className="mt-1 text-muted-foreground">
                                {new Intl.DateTimeFormat("en-ZA", { dateStyle: "medium" }).format(
                                  new Date(request.createdAt),
                                )}
                              </p>
                            </div>
                            <span className="rounded-full bg-artisan-bone px-3 py-1 text-xs font-medium text-artisan-sienna">
                              {formatVendorStatus(request.status)}
                            </span>
                          </div>
                          <div className="mt-4 grid gap-2 text-muted-foreground">
                            <p>
                              Items:{" "}
                              {request.items
                                .map((item) => `${item.quantity ?? 1} x ${item.name ?? item.key}`)
                                .join(", ")}
                            </p>
                            <p>Total: {request.amount != null ? formatPrice(request.amount) : "Quote pending"}</p>
                            {request.deliveryAddress ? <p>Delivery: {request.deliveryAddress}</p> : null}
                            {request.notes ? <p>Notes: {request.notes}</p> : null}
                            {request.statusReason ? <p>Payment note: {request.statusReason}</p> : null}
                          </div>
                          {(request.trackingNumber || request.courierName) ? (
                            <div className="mt-4 rounded-2xl bg-artisan-bone/50 p-3">
                              <p className="font-medium text-artisan-sienna">Fulfilment</p>
                              <p className="mt-1 text-muted-foreground">
                                {request.courierName ?? "Courier"} {request.trackingNumber ?? ""}
                              </p>
                            </div>
                          ) : null}
                          {request.status === "awaiting_payment" ? (
                            <form action={payExistingStationeryRequest} className="mt-4">
                              <input type="hidden" name="requestId" value={request.id} />
                              <Button className="w-full rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
                                Pay now
                              </Button>
                            </form>
                          ) : null}
                        </div>
                      ))}
                </div>
              )}
            </div>
          )}
        </VendorPanel>
        <VendorPanel
          title="Create request"
          description="Choose branded packaging items, add delivery details, then continue to PayFast."
        >
          <VendorStationeryRequestForm disabled={!shop} />
        </VendorPanel>
      </div>
    </div>
  );
}
