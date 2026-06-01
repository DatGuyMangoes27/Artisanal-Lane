import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { requireBuyerAccountSession } from "@/lib/marketplace/account";
import { listBuyerDisputes } from "@/lib/marketplace/dispute-data";
import { formatDisputeStatus } from "@/lib/marketplace/disputes";

export default async function BuyerDisputesPage() {
  const { user } = await requireBuyerAccountSession("/account/disputes");
  const disputes = await listBuyerDisputes(user.id);

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
              Disputes
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        <div className="mt-10 space-y-4">
          {disputes.length === 0 ? (
            <Card className="border-artisan-clay bg-card text-center">
              <CardContent className="p-8">
                <h2 className="font-serif text-2xl font-bold text-foreground">No disputes</h2>
                <p className="mt-2 text-muted-foreground">
                  If an order arrives damaged or does not arrive, open a dispute from the order detail page.
                </p>
              </CardContent>
            </Card>
          ) : null}
          {disputes.map((dispute) => (
            <Card key={dispute.id} className="border-artisan-clay bg-card">
              <CardContent className="p-6">
                <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="font-serif text-2xl font-bold text-foreground">
                        Order #{dispute.orderId.slice(0, 8).toUpperCase()}
                      </h2>
                      <Badge variant="outline">{formatDisputeStatus(dispute.status)}</Badge>
                    </div>
                    <p className="mt-3 text-sm leading-6 text-muted-foreground">{dispute.reason}</p>
                    {dispute.resolution ? (
                      <p className="mt-2 text-sm leading-6 text-muted-foreground">
                        Resolution: {dispute.resolution}
                      </p>
                    ) : null}
                  </div>
                  <Button asChild className="rounded-full">
                    <Link href={`/account/orders/${dispute.orderId}`}>View order</Link>
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </main>
    </div>
  );
}
