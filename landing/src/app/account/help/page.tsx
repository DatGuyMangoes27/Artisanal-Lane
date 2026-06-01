import Link from "next/link";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { requireBuyerAccountSession } from "@/lib/marketplace/account";

const helpLinks = [
  {
    href: "/account/orders",
    title: "Orders and delivery",
    body: "Track orders, confirm receipt, review items, and raise a dispute from your order detail page.",
  },
  {
    href: "/account/messages",
    title: "Messages",
    body: "Contact sellers about product, delivery, and order questions.",
  },
  {
    href: "/privacy",
    title: "Privacy Policy",
    body: "Read how Artisan Lane handles your personal information.",
  },
  {
    href: "/terms",
    title: "Terms of Service",
    body: "Review marketplace, buyer, seller, and escrow terms.",
  },
];

export default async function BuyerHelpPage() {
  await requireBuyerAccountSession("/account/help");

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
              Help and legal
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        <section className="mt-10 grid gap-4 md:grid-cols-2">
          {helpLinks.map((item) => (
            <Card key={item.href} className="border-artisan-clay bg-card">
              <CardContent className="p-6">
                <h2 className="font-serif text-2xl font-bold text-foreground">{item.title}</h2>
                <p className="mt-2 text-sm leading-6 text-muted-foreground">{item.body}</p>
                <Button asChild className="mt-6 rounded-full">
                  <Link href={item.href}>Open</Link>
                </Button>
              </CardContent>
            </Card>
          ))}
        </section>
      </main>
    </div>
  );
}
