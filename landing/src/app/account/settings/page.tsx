import Link from "next/link";

import { signOutBuyerAccount } from "@/app/account/actions";
import { DeleteAccountForm } from "@/components/account/delete-account-form";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { requireBuyerAccountSession } from "@/lib/marketplace/account";

export default async function BuyerSettingsPage() {
  await requireBuyerAccountSession("/account/settings");

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
              Settings
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        <Card className="mt-10 border-artisan-clay bg-card">
          <CardContent className="space-y-4 p-6">
            <h2 className="font-serif text-2xl font-bold text-foreground">Account controls</h2>
            <p className="text-sm leading-6 text-muted-foreground">
              Log out of this browser when you are done shopping or managing your account.
            </p>
            <form action={signOutBuyerAccount}>
              <Button type="submit" className="rounded-full">
                Log out
              </Button>
            </form>
          </CardContent>
        </Card>

        <Card className="mt-6 border-red-200 bg-card">
          <CardContent className="space-y-4 p-6">
            <h2 className="font-serif text-2xl font-bold text-red-800">Danger zone</h2>
            <p className="text-sm leading-6 text-muted-foreground">
              Deleting your account is permanent and removes your login. Order and application records
              needed for marketplace history may be preserved.
            </p>
            <DeleteAccountForm />
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
