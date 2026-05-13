import Link from "next/link";

import { updateBuyerProfile } from "@/app/account/actions";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { requireBuyerAccountSession } from "@/lib/marketplace/account";
import { getBuyerInitial } from "@/lib/marketplace/buyer-profile";

export default async function BuyerProfilePage() {
  const { user, profile } = await requireBuyerAccountSession("/account/profile");

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-3xl px-4 py-10 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
              Buyer account
            </p>
            <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
              Profile
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        <Card className="mt-10 border-artisan-clay bg-card">
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="flex size-20 items-center justify-center rounded-full bg-artisan-clay font-serif text-3xl font-bold text-white">
                {getBuyerInitial(profile ?? { display_name: null, email: user.email ?? null })}
              </div>
              <div>
                <h2 className="font-serif text-2xl font-bold text-foreground">
                  {profile?.display_name || "Artisan Lane buyer"}
                </h2>
                <p className="text-sm text-muted-foreground">{profile?.email ?? user.email}</p>
              </div>
            </div>

            <form action={updateBuyerProfile} className="mt-8 grid gap-4">
              <label className="space-y-2 text-sm font-medium text-foreground">
                Display name
                <input
                  name="displayName"
                  defaultValue={profile?.display_name ?? ""}
                  required
                  className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                />
              </label>
              <label className="space-y-2 text-sm font-medium text-foreground">
                Phone number
                <input
                  name="phone"
                  defaultValue={profile?.phone ?? ""}
                  className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                />
              </label>
              <label className="space-y-2 text-sm font-medium text-muted-foreground">
                Email
                <input
                  value={profile?.email ?? user.email ?? ""}
                  readOnly
                  className="w-full rounded-xl border border-artisan-clay bg-secondary px-3 py-2"
                />
              </label>
              <p className="text-sm text-muted-foreground">
                Email changes still happen through your login provider. This page updates your Artisan Lane
                display details.
              </p>
              <Button type="submit" className="rounded-full">Save profile</Button>
            </form>
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
