import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { listBuyerOrders, requireBuyerAccountSession } from "@/lib/marketplace/account";
import { formatOrderStatus } from "@/lib/marketplace/orders";

export default async function AccountPage() {
  const { user, profile } = await requireBuyerAccountSession("/account");
  const orders = await listBuyerOrders(user.id);
  const activeOrders = orders.filter((order) =>
    ["pending", "paid", "shipped", "delivered", "disputed"].includes(order.status),
  );
  const latestOrder = orders[0] ?? null;

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          Buyer account
        </p>
        <div className="mt-3 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <h1 className="font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
              Welcome{profile?.display_name ? `, ${profile.display_name}` : ""}
            </h1>
            <p className="mt-3 text-muted-foreground">
              {profile?.email ?? user.email ?? "Manage your Artisan Lane buyer activity."}
            </p>
          </div>
          <Button asChild className="rounded-full">
            <Link href="/shop">Continue shopping</Link>
          </Button>
        </div>

        <section className="mt-10 grid gap-4 md:grid-cols-3">
          <Card className="border-artisan-clay bg-card">
            <CardContent className="p-6">
              <p className="text-sm text-muted-foreground">Total orders</p>
              <p className="mt-2 text-4xl font-bold text-foreground">{orders.length}</p>
            </CardContent>
          </Card>
          <Card className="border-artisan-clay bg-card">
            <CardContent className="p-6">
              <p className="text-sm text-muted-foreground">Active orders</p>
              <p className="mt-2 text-4xl font-bold text-foreground">{activeOrders.length}</p>
            </CardContent>
          </Card>
          <Card className="border-artisan-clay bg-card">
            <CardContent className="p-6">
              <p className="text-sm text-muted-foreground">Latest status</p>
              <p className="mt-2 text-2xl font-bold text-foreground">
                {latestOrder ? formatOrderStatus(latestOrder.status) : "No orders yet"}
              </p>
            </CardContent>
          </Card>
        </section>

        <section className="mt-10 grid gap-4 md:grid-cols-2">
          <Card className="border-artisan-clay bg-card">
            <CardContent className="p-6">
              <h2 className="font-serif text-2xl font-bold text-foreground">Orders</h2>
              <p className="mt-2 text-sm leading-6 text-muted-foreground">
                View your TradeSafe orders, delivery details, tracking, and payment state.
              </p>
              <Button asChild className="mt-6 rounded-full">
                <Link href="/account/orders">View orders</Link>
              </Button>
            </CardContent>
          </Card>
          <Card className="border-artisan-clay bg-card">
            <CardContent className="p-6">
              <h2 className="font-serif text-2xl font-bold text-foreground">Messages</h2>
              <p className="mt-2 text-sm leading-6 text-muted-foreground">
                Buyer-seller messages are the next account area to bring across from the app.
              </p>
              <Button disabled className="mt-6 rounded-full">
                Coming next
              </Button>
            </CardContent>
          </Card>
        </section>
      </main>
    </div>
  );
}
