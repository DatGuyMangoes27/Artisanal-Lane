import Image from "next/image";
import { notFound } from "next/navigation";

import { Button } from "@/components/ui/button";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { markVendorOrderShipped } from "@/app/vendor/actions";
import { getVendorOrder, requireVendorShop } from "@/lib/marketplace/vendor-data";
import { formatPrice } from "@/lib/marketplace/format";
import { formatVendorStatus } from "@/lib/marketplace/vendor-utils";

function AddressBlock({ value }: { value: Record<string, unknown> | null }) {
  if (!value) {
    return <p className="text-sm text-muted-foreground">No address captured.</p>;
  }

  return (
    <pre className="whitespace-pre-wrap rounded-2xl bg-artisan-bone/50 p-4 text-xs text-artisan-sienna">
      {JSON.stringify(value, null, 2)}
    </pre>
  );
}

export default async function VendorOrderDetailPage({
  params,
}: {
  params: Promise<{ orderId: string }>;
}) {
  const { orderId } = await params;
  const { shop } = await requireVendorShop(`/vendor/orders/${orderId}`);
  const order = await getVendorOrder(shop.id, orderId);

  if (!order) {
    notFound();
  }

  return (
    <div>
      <VendorPageHeader
        eyebrow="Fulfilment"
        title={`Order #${order.shortId}`}
        description={`${formatVendorStatus(order.status)} · ${formatPrice(order.total + order.shippingCost)} · ${order.buyerName ?? order.buyerEmail ?? "Buyer"}`}
      />

      <div className="grid gap-6 xl:grid-cols-[1fr_0.8fr]">
        <VendorPanel title="Items">
          <div className="space-y-4">
            {order.items.map((item) => (
              <div key={item.id} className="grid gap-4 rounded-2xl border border-artisan-clay/70 p-4 md:grid-cols-[4rem_1fr_auto]">
                <div className="relative h-16 w-16 overflow-hidden rounded-xl bg-artisan-bone">
                  {item.image ? (
                    <Image src={item.image} alt={item.productTitle} fill className="object-cover" />
                  ) : null}
                </div>
                <div>
                  <p className="font-medium text-artisan-sienna">{item.productTitle}</p>
                  <p className="text-sm text-muted-foreground">
                    {item.variantName ?? "Standard"} · Qty {item.quantity}
                  </p>
                </div>
                <p className="font-medium text-artisan-sienna">{formatPrice(item.lineTotal)}</p>
              </div>
            ))}
          </div>
        </VendorPanel>

        <div className="space-y-6">
          <VendorPanel title="Buyer and delivery">
            <div className="space-y-4 text-sm">
              <p>
                Buyer:{" "}
                <span className="font-medium text-artisan-sienna">
                  {order.buyerName ?? order.buyerEmail ?? "Buyer"}
                </span>
              </p>
              <p>Shipping method: {formatVendorStatus(order.shippingMethod)}</p>
              <p>Payment state: {formatVendorStatus(order.paymentState)}</p>
              <AddressBlock value={order.shippingAddress} />
              {order.isGift ? (
                <div className="rounded-2xl border border-artisan-clay/70 p-4">
                  <p className="font-medium text-artisan-sienna">Gift order</p>
                  <p className="text-muted-foreground">Recipient: {order.giftRecipient ?? "Not set"}</p>
                  <p className="text-muted-foreground">Message: {order.giftMessage ?? "No message"}</p>
                </div>
              ) : null}
            </div>
          </VendorPanel>

          <VendorPanel title="Mark shipped" description="This uses the shared mark-order-shipped Edge Function.">
            <form action={markVendorOrderShipped} className="grid gap-3">
              <input type="hidden" name="orderId" value={order.id} />
              <input
                name="trackingNumber"
                defaultValue={order.trackingNumber ?? ""}
                placeholder="Tracking number"
                className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
              />
              <input
                name="trackingUrl"
                defaultValue={order.trackingUrl ?? ""}
                placeholder="Tracking URL"
                className="rounded-2xl border border-artisan-clay px-4 py-3 text-sm"
              />
              <Button className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
                Mark order shipped
              </Button>
            </form>
          </VendorPanel>
        </div>
      </div>
    </div>
  );
}
