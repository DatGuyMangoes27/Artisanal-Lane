import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { listBuyerOrders, requireBuyerAccountSession } from "@/lib/marketplace/account";
import { formatPrice } from "@/lib/marketplace/format";
import {
  formatOrderStatus,
  formatShippingMethod,
  getOrderGrandTotal,
} from "@/lib/marketplace/orders";

export default async function BuyerOrdersPage() {
  const { user } = await requireBuyerAccountSession("/account/orders");
  const orders = await listBuyerOrders(user.id);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-5xl px-4 py-10 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
              Buyer account
            </p>
            <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
              Your orders
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        {orders.length === 0 ? (
          <Card className="mt-10 border-artisan-clay bg-card text-center">
            <CardContent className="p-8">
              <h2 className="font-serif text-2xl font-bold text-foreground">No orders yet</h2>
              <p className="mt-2 text-muted-foreground">
                When you complete TradeSafe checkout, your web and app orders will appear here.
              </p>
              <Button asChild className="mt-6 rounded-full">
                <Link href="/shop">Start shopping</Link>
              </Button>
            </CardContent>
          </Card>
        ) : (
          <div className="mt-10 space-y-4">
            {orders.map((order) => (
              <Link
                key={order.id}
                href={`/account/orders/${order.id}`}
                className="block rounded-[2rem] focus:outline-none focus:ring-2 focus:ring-artisan-terracotta"
              >
                <Card className="border-artisan-clay bg-card transition hover:border-artisan-terracotta">
                  <CardContent className="grid gap-4 p-6 md:grid-cols-[1fr_auto] md:items-center">
                    <div>
                      <div className="flex flex-wrap items-center gap-3">
                        <h2 className="font-serif text-2xl font-bold text-foreground">
                          Order #{order.shortId}
                        </h2>
                        <Badge variant="outline">{formatOrderStatus(order.status)}</Badge>
                      </div>
                      <p className="mt-2 text-sm text-muted-foreground">
                        {order.shopName} • {formatShippingMethod(order.shippingMethod)}
                      </p>
                      <p className="mt-1 text-sm text-muted-foreground">
                        {new Date(order.createdAt).toLocaleDateString("en-ZA", {
                          year: "numeric",
                          month: "short",
                          day: "numeric",
                        })}
                      </p>
                    </div>
                    <div className="text-left md:text-right">
                      <p className="text-lg font-bold text-foreground">
                        {formatPrice(getOrderGrandTotal(order))}
                      </p>
                      <p className="text-sm text-muted-foreground">
                        {order.items.length} {order.items.length === 1 ? "item" : "items"}
                      </p>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
