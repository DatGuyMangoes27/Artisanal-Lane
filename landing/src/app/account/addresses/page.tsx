import Link from "next/link";

import { saveAddress } from "@/app/account/actions";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { requireBuyerAccountSession } from "@/lib/marketplace/account";
import { getAddressSummary } from "@/lib/marketplace/buyer-preferences";
import { listSavedAddresses } from "@/lib/marketplace/buyer-preferences-data";

const provinces = [
  "Eastern Cape",
  "Free State",
  "Gauteng",
  "KwaZulu-Natal",
  "Limpopo",
  "Mpumalanga",
  "Northern Cape",
  "North West",
  "Western Cape",
];

export default async function AddressesPage() {
  const { user } = await requireBuyerAccountSession("/account/addresses");
  const addresses = await listSavedAddresses(user.id);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[1fr_420px] lg:px-8">
        <section>
          <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
                Buyer account
              </p>
              <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
                Saved addresses
              </h1>
            </div>
            <Button asChild variant="outline" className="rounded-full">
              <Link href="/account">Back to account</Link>
            </Button>
          </div>

          <div className="mt-10 space-y-4">
            {addresses.length === 0 ? (
              <Card className="border-artisan-clay bg-card">
                <CardContent className="p-8 text-center text-muted-foreground">
                  You have no saved addresses yet.
                </CardContent>
              </Card>
            ) : (
              addresses.map((address) => (
                <Card key={address.id} className="border-artisan-clay bg-card">
                  <CardContent className="p-6">
                    <div className="flex flex-wrap items-center gap-3">
                      <h2 className="font-serif text-2xl font-bold text-foreground">{address.name}</h2>
                      {address.isDefault ? <Badge>Default</Badge> : null}
                    </div>
                    <p className="mt-2 text-muted-foreground">{getAddressSummary(address)}</p>
                    <p className="mt-1 text-sm text-muted-foreground">{address.phone}</p>
                  </CardContent>
                </Card>
              ))
            )}
          </div>
        </section>

        <aside className="h-fit rounded-[2rem] border border-artisan-clay bg-card p-6 shadow-sm">
          <h2 className="font-serif text-2xl font-bold text-foreground">Add address</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Delivery addresses must be in South Africa.
          </p>
          <form action={saveAddress} className="mt-6 space-y-4">
            <input name="name" required placeholder="Address name" className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
            <input name="street" required placeholder="Street address" className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
            <div className="grid gap-4 sm:grid-cols-2">
              <input name="city" required placeholder="City" className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
              <input name="postalCode" required placeholder="Postal code" className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
            </div>
            <select name="province" required className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2">
              <option value="">Choose province</option>
              {provinces.map((province) => (
                <option key={province} value={province}>{province}</option>
              ))}
            </select>
            <input name="phone" required placeholder="Phone number" className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
            <label className="flex items-center gap-3 text-sm text-muted-foreground">
              <input name="isDefault" type="checkbox" /> Make default address
            </label>
            <Button type="submit" className="w-full rounded-full">Save address</Button>
          </form>
        </aside>
      </main>
    </div>
  );
}
