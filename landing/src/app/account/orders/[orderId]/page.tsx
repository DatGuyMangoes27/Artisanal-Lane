import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { openBuyerDispute } from "@/app/account/disputes/actions";
import { submitProductReview } from "@/app/account/reviews/actions";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { getBuyerOrder, requireBuyerAccountSession } from "@/lib/marketplace/account";
import { getActiveDisputeForOrder } from "@/lib/marketplace/dispute-data";
import {
  canOpenDisputeForOrderStatus,
  formatDisputeStatus,
} from "@/lib/marketplace/disputes";
import { formatPrice } from "@/lib/marketplace/format";
import {
  canConfirmReceipt,
  formatLeadTimeRange,
  formatOrderStatus,
  formatShippingMethod,
  getDeliveryStatusMessage,
  getOrderGrandTotal,
  getOrderPickupPointSummary,
  normalizeTrackingUrl,
} from "@/lib/marketplace/orders";
import { canReviewOrderStatus } from "@/lib/marketplace/reviews";

import { confirmBuyerOrderReceipt } from "../actions";
import { createBuyerThreadForShop } from "../../messages/actions";

type BuyerOrderDetailPageProps = {
  params: Promise<{
    orderId: string;
  }>;
};

export default async function BuyerOrderDetailPage({ params }: BuyerOrderDetailPageProps) {
  const { orderId } = await params;
  const { user } = await requireBuyerAccountSession(`/account/orders/${orderId}`);
  const [order, activeDispute] = await Promise.all([
    getBuyerOrder(user.id, orderId),
    getActiveDisputeForOrder(orderId),
  ]);

  if (!order) {
    notFound();
  }

  const pickupSummary = getOrderPickupPointSummary(order);
  const canReviewItems = canReviewOrderStatus(order.status);
  const canOpenDispute = canOpenDisputeForOrderStatus(order.status);
  const canConfirmOrderReceipt = canConfirmReceipt(order);
  const trackingHref = normalizeTrackingUrl(order.trackingUrl);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:px-8">
        <Button asChild variant="ghost" className="mb-6 rounded-full">
          <Link href="/account/orders">Back to orders</Link>
        </Button>

        <div className="grid gap-8 lg:grid-cols-[1fr_360px]">
          <section className="space-y-6">
            <Card className="border-artisan-clay bg-card">
              <CardContent className="p-6">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
                      Order #{order.shortId}
                    </p>
                    <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground">
                      {order.shopName}
                    </h1>
                    <p className="mt-2 text-sm text-muted-foreground">
                      Placed{" "}
                      {new Date(order.createdAt).toLocaleDateString("en-ZA", {
                        year: "numeric",
                        month: "long",
                        day: "numeric",
                      })}
                    </p>
                  </div>
                  <Badge variant="outline">{formatOrderStatus(order.status)}</Badge>
                </div>
              </CardContent>
            </Card>

            <Card className="border-artisan-clay bg-card">
              <CardContent className="space-y-4 p-6">
                <h2 className="font-serif text-2xl font-bold text-foreground">Items</h2>
                {order.items.map((item) => (
                  <div
                    key={item.id}
                    className="grid gap-4 rounded-2xl border border-artisan-clay bg-background p-4 sm:grid-cols-[88px_1fr]"
                  >
                    <div className="relative aspect-square overflow-hidden rounded-xl bg-secondary">
                      {item.image ? (
                        <Image src={item.image} alt={item.title} fill sizes="88px" className="object-cover" />
                      ) : null}
                    </div>
                    <div className="flex flex-col justify-between gap-3">
                      <div>
                        <p className="font-semibold text-foreground">{item.title}</p>
                        {item.variantName ? (
                          <p className="text-sm text-muted-foreground">{item.variantName}</p>
                        ) : null}
                        {item.isMadeToOrder ? (
                          <p className="mt-1 text-sm font-medium text-artisan-terracotta">
                            Made to order
                            {formatLeadTimeRange(item.leadMinDays, item.leadMaxDays)
                              ? ` · ships in ${formatLeadTimeRange(item.leadMinDays, item.leadMaxDays)}`
                              : ""}
                          </p>
                        ) : null}
                        {item.isMadeToOrder && item.customNote ? (
                          <p className="mt-1 text-sm italic text-muted-foreground">
                            “{item.customNote}”
                          </p>
                        ) : null}
                      </div>
                      <div className="flex flex-wrap justify-between gap-3 text-sm">
                        <p className="text-muted-foreground">
                          {item.quantity} × {formatPrice(item.unitPrice)}
                        </p>
                        <p className="font-semibold text-foreground">{formatPrice(item.lineTotal)}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>

            {canReviewItems ? (
              <Card className="border-artisan-clay bg-card">
                <CardContent className="space-y-4 p-6">
                  <h2 className="font-serif text-2xl font-bold text-foreground">Review your items</h2>
                  <p className="text-sm text-muted-foreground">
                    Help other buyers by reviewing the pieces you received.
                  </p>
                  {order.items.map((item) => (
                    <form
                      key={`review-${item.id}`}
                      action={submitProductReview}
                      className="rounded-2xl border border-artisan-clay bg-background p-4"
                    >
                      <input type="hidden" name="productId" value={item.productId} />
                      <input type="hidden" name="redirectTo" value={`/account/orders/${order.id}`} />
                      <p className="font-semibold text-foreground">{item.title}</p>
                      {item.variantName ? (
                        <p className="text-sm text-muted-foreground">{item.variantName}</p>
                      ) : null}
                      <div className="mt-4 grid gap-3 sm:grid-cols-[140px_1fr]">
                        <label className="text-sm font-medium text-foreground">
                          Rating
                          <select
                            name="rating"
                            defaultValue={5}
                            className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                          >
                            {[5, 4, 3, 2, 1].map((rating) => (
                              <option key={rating} value={rating}>
                                {rating} star{rating === 1 ? "" : "s"}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label className="text-sm font-medium text-foreground">
                          Review
                          <textarea
                            name="reviewText"
                            rows={3}
                            className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                            placeholder="Share your thoughts on this item."
                          />
                        </label>
                      </div>
                      <Button type="submit" className="mt-4 rounded-full">
                        Submit review
                      </Button>
                    </form>
                  ))}
                </CardContent>
              </Card>
            ) : null}
          </section>

          <aside className="space-y-6">
            <Card className="border-artisan-clay bg-card">
              <CardContent className="p-6">
                <h2 className="font-serif text-2xl font-bold text-foreground">Summary</h2>
                <div className="mt-5 space-y-3 text-sm">
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Items</span>
                    <span className="font-semibold text-foreground">{formatPrice(order.total)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Delivery</span>
                    <span className="font-semibold text-foreground">{formatPrice(order.shippingCost)}</span>
                  </div>
                  {order.isGift ? (
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Gift fee</span>
                      <span className="font-semibold text-foreground">R30.00</span>
                    </div>
                  ) : null}
                  <div className="flex justify-between border-t border-artisan-clay pt-3 text-base">
                    <span className="font-semibold text-foreground">Total</span>
                    <span className="font-bold text-foreground">{formatPrice(getOrderGrandTotal(order))}</span>
                  </div>
                </div>
                {order.paymentUrl && ["pending", "cancelled"].includes(order.status) ? (
                  <Button asChild className="mt-6 w-full rounded-full">
                    <Link href={order.paymentUrl}>Resume payment</Link>
                  </Button>
                ) : null}
                <form action={createBuyerThreadForShop} className="mt-3">
                  <input type="hidden" name="shopId" value={order.shopId} />
                  <input type="hidden" name="redirectTo" value={`/account/orders/${order.id}`} />
                  <Button type="submit" variant="outline" className="w-full rounded-full">
                    Message seller
                  </Button>
                </form>
              </CardContent>
            </Card>

            <Card className="border-artisan-clay bg-card">
              <CardContent className="space-y-3 p-6 text-sm">
                <h2 className="font-serif text-2xl font-bold text-foreground">Delivery</h2>
                <p className="leading-6 text-muted-foreground">{getDeliveryStatusMessage(order)}</p>
                <p>
                  <span className="font-semibold text-foreground">Method: </span>
                  <span className="text-muted-foreground">{formatShippingMethod(order.shippingMethod)}</span>
                </p>
                {pickupSummary ? (
                  <p>
                    <span className="font-semibold text-foreground">Pickup: </span>
                    <span className="text-muted-foreground">{pickupSummary}</span>
                  </p>
                ) : null}
                {order.trackingNumber ? (
                  <p>
                    <span className="font-semibold text-foreground">Tracking: </span>
                    <span className="text-muted-foreground">{order.trackingNumber}</span>
                  </p>
                ) : null}
                {trackingHref ? (
                  <Button asChild variant="outline" className="mt-2 rounded-full">
                    <a href={trackingHref} target="_blank" rel="noreferrer">
                      Track parcel
                    </a>
                  </Button>
                ) : null}
              </CardContent>
            </Card>

            {canConfirmOrderReceipt ? (
              <Card className="border-artisan-clay bg-card">
                <CardContent className="space-y-4 p-6 text-sm">
                  <h2 className="font-serif text-2xl font-bold text-foreground">Confirm receipt</h2>
                  <p className="leading-6 text-muted-foreground">
                    Only confirm once you have received the order and are happy with it. This releases
                    the TradeSafe escrow payment to the artisan and marks the order complete.
                  </p>
                  <form action={confirmBuyerOrderReceipt}>
                    <input type="hidden" name="orderId" value={order.id} />
                    <input type="hidden" name="redirectTo" value={`/account/orders/${order.id}`} />
                    <Button type="submit" className="w-full rounded-full">
                      Yes, I received my order
                    </Button>
                  </form>
                </CardContent>
              </Card>
            ) : null}

            <Card className="border-artisan-clay bg-card">
              <CardContent className="space-y-3 p-6 text-sm">
                <h2 className="font-serif text-2xl font-bold text-foreground">Payment</h2>
                <p>
                  <span className="font-semibold text-foreground">Provider: </span>
                  <span className="text-muted-foreground">{order.paymentProvider ?? "TradeSafe"}</span>
                </p>
                <p>
                  <span className="font-semibold text-foreground">State: </span>
                  <span className="text-muted-foreground">{formatOrderStatus(order.paymentState)}</span>
                </p>
              </CardContent>
            </Card>

            <Card className="border-artisan-clay bg-card">
              <CardContent className="space-y-4 p-6 text-sm">
                <h2 className="font-serif text-2xl font-bold text-foreground">Need help?</h2>
                {activeDispute ? (
                  <div className="rounded-2xl border border-red-200 bg-red-50 p-4 text-red-800">
                    <p className="font-semibold">Dispute {formatDisputeStatus(activeDispute.status)}</p>
                    <p className="mt-2 leading-6">{activeDispute.reason}</p>
                    {activeDispute.resolution ? (
                      <p className="mt-2 leading-6">Resolution: {activeDispute.resolution}</p>
                    ) : null}
                  </div>
                ) : canOpenDispute ? (
                  <form action={openBuyerDispute} className="space-y-3">
                    <input type="hidden" name="orderId" value={order.id} />
                    <input type="hidden" name="redirectTo" value={`/account/orders/${order.id}`} />
                    <p className="text-muted-foreground">
                      If something is wrong with this delivery, open a dispute. This starts a case with
                      the seller and Artisan Lane admin team.
                    </p>
                    <label className="block font-medium text-foreground">
                      What happened?
                      <textarea
                        name="reason"
                        required
                        rows={4}
                        className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                        placeholder="Describe the issue with your order."
                      />
                    </label>
                    <Button type="submit" variant="outline" className="w-full rounded-full border-red-200 text-red-700 hover:text-red-800">
                      Raise dispute
                    </Button>
                  </form>
                ) : (
                  <p className="text-muted-foreground">
                    Disputes become available once an order has shipped or been delivered. You can still
                    message the seller from the order summary.
                  </p>
                )}
              </CardContent>
            </Card>
          </aside>
        </div>
      </main>
    </div>
  );
}
