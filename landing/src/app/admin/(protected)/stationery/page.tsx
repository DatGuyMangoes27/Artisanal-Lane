import Link from "next/link";

import { StationeryRequestForm } from "@/components/admin/stationery-request-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { listStationeryRequests } from "@/lib/admin-data";

function readParam(
  value: string | string[] | undefined,
  fallback = "",
) {
  return typeof value === "string" ? value : fallback;
}

function formatItems(
  items: Array<{ key?: string; name?: string; quantity?: number }>,
) {
  return items
    .map((item) => `${item.quantity ?? 0} x ${item.name ?? item.key ?? "Item"}`)
    .join(", ");
}

export default async function AdminStationeryPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const params = await searchParams;
  const query = readParam(params.query);
  const status = readParam(params.status, "all");
  const sort = readParam(params.sort, "newest");
  const requests = await listStationeryRequests({ query, status, sort });

  return (
    <>
      <AdminPageHeader
        eyebrow="Internal Fulfilment"
        title="Stationery Orders"
        description="Manage branded stationery requests from artisan shops and move them from queue to delivery."
      />

      <PanelCard
        title="Fulfilment Queue"
        description="Update request status, add dispatch details, and leave internal notes for the operations team."
      >
        <form className="mb-6 grid gap-3 md:grid-cols-4" method="get">
          <input
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={query}
            name="query"
            placeholder="Search shop, vendor, address, notes"
            type="search"
          />
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={status}
            name="status"
          >
            <option value="all">All statuses</option>
            <option value="awaiting_payment">Awaiting payment</option>
            <option value="paid">Paid</option>
            <option value="processing">Processing</option>
            <option value="shipped">Shipped</option>
            <option value="delivered">Delivered</option>
            <option value="cancelled">Cancelled</option>
          </select>
          <select
            className="rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={sort}
            name="sort"
          >
            <option value="newest">Newest first</option>
            <option value="oldest">Oldest first</option>
            <option value="status">Status A-Z</option>
            <option value="quantity-high">Highest quantity</option>
          </select>
          <div className="flex gap-3">
            <Button className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90" type="submit">
              Apply
            </Button>
            <Button asChild type="button" variant="outline">
              <Link href="/admin/stationery">Reset</Link>
            </Button>
          </div>
        </form>

        <div className="space-y-4">
          {requests.length === 0 ? (
            <div className="rounded-3xl border border-dashed border-artisan-clay bg-white p-8 text-sm text-muted-foreground">
              No stationery requests match the current filters.
            </div>
          ) : null}

          {requests.map((request) => (
            <div
              key={request.id}
              className="rounded-3xl border border-artisan-clay bg-white p-5"
            >
              <div className="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
                <div className="space-y-3">
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-xl font-semibold text-artisan-sienna">
                      {request.shop?.name ?? "Unknown shop"}
                    </h3>
                    <StatusBadge value={request.status} />
                  </div>

                  <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-2 xl:grid-cols-3">
                    <p>
                      <span className="font-medium text-artisan-sienna">Vendor:</span>{" "}
                      {request.vendor?.display_name ?? request.vendor?.email ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Requested:</span>{" "}
                      {new Date(request.created_at).toLocaleDateString()}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Total units:</span>{" "}
                      {request.totalQuantity}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Amount:</span>{" "}
                      {(request.currency ?? "ZAR")} {Number(request.amount ?? 0).toFixed(2)}
                    </p>
                    <p className="md:col-span-2 xl:col-span-3">
                      <span className="font-medium text-artisan-sienna">Items:</span>{" "}
                      {formatItems(request.items)}
                    </p>
                    {request.paid_at ? (
                      <p>
                        <span className="font-medium text-artisan-sienna">Paid at:</span>{" "}
                        {new Date(request.paid_at).toLocaleString()}
                      </p>
                    ) : null}
                    {request.payfast_payment_id ? (
                      <p className="md:col-span-2 xl:col-span-3">
                        <span className="font-medium text-artisan-sienna">
                          PayFast payment ID:
                        </span>{" "}
                        {request.payfast_payment_id}
                      </p>
                    ) : null}
                    {request.status_reason ? (
                      <p className="md:col-span-2 xl:col-span-3">
                        <span className="font-medium text-artisan-sienna">
                          Payment note:
                        </span>{" "}
                        {request.status_reason}
                      </p>
                    ) : null}
                    <p className="md:col-span-2 xl:col-span-3">
                      <span className="font-medium text-artisan-sienna">
                        Delivery address:
                      </span>{" "}
                      {request.delivery_address ?? "Not provided"}
                    </p>
                    {request.notes ? (
                      <p className="md:col-span-2 xl:col-span-3">
                        <span className="font-medium text-artisan-sienna">
                          Vendor notes:
                        </span>{" "}
                        {request.notes}
                      </p>
                    ) : null}
                    {request.fulfilledByProfile ? (
                      <p>
                        <span className="font-medium text-artisan-sienna">
                          Last handled by:
                        </span>{" "}
                        {request.fulfilledByProfile.display_name ??
                          request.fulfilledByProfile.email ??
                          "Admin"}
                      </p>
                    ) : null}
                    {request.fulfilled_at ? (
                      <p>
                        <span className="font-medium text-artisan-sienna">
                          Fulfilment date:
                        </span>{" "}
                        {new Date(request.fulfilled_at).toLocaleString()}
                      </p>
                    ) : null}
                  </div>
                </div>

                <StationeryRequestForm request={request} />
              </div>
            </div>
          ))}
        </div>
      </PanelCard>
    </>
  );
}
