import Link from "next/link";

import { Button } from "@/components/ui/button";
import { VendorSidebarNav } from "@/components/vendor/vendor-sidebar-nav";
import type { VendorShop } from "@/lib/marketplace/vendor-data";

export function VendorShell({
  children,
  shop,
}: {
  children: React.ReactNode;
  shop: VendorShop | null;
}) {
  return (
    <div className="min-h-screen bg-artisan-bone/40">
      <div className="mx-auto flex w-full max-w-7xl flex-col gap-6 px-4 py-6 lg:flex-row">
        <aside className="lg:sticky lg:top-6 lg:max-h-[calc(100vh-3rem)] lg:w-72 lg:self-start lg:overflow-y-auto">
          <div className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-4 shadow-xl">
            <Link href="/" className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">
              Artisan Lane
            </Link>
            <div className="mt-4 rounded-3xl bg-artisan-bone/70 p-4">
              <p className="text-sm text-muted-foreground">Vendor portal</p>
              <h1 className="mt-1 text-2xl font-semibold text-artisan-sienna">
                {shop?.name ?? "Your shop"}
              </h1>
              {shop?.location ? (
                <p className="mt-1 text-sm text-muted-foreground">{shop.location}</p>
              ) : null}
              {shop?.isActive ? (
                <Button asChild className="mt-4 w-full rounded-full" variant="outline">
                  <Link href={`/shops/${shop.slug ?? shop.id}`}>View public profile</Link>
                </Button>
              ) : null}
              {!shop ? (
                <Button asChild className="mt-4 w-full rounded-full" variant="outline">
                  <Link href="/vendor/profile/shop">Complete shop setup</Link>
                </Button>
              ) : null}
            </div>
            <VendorSidebarNav />
          </div>
        </aside>
        <main className="min-w-0 flex-1">{children}</main>
      </div>
    </div>
  );
}

export function VendorSetupRequired({
  title = "Complete your shop profile first",
  description = "This section unlocks once your artisan shop profile exists. Add your shop name, story, location, images, shipping defaults, and market pickup details to continue.",
}: {
  title?: string;
  description?: string;
}) {
  return (
    <VendorPanel title={title} description={description}>
      <div className="flex flex-col gap-3 rounded-3xl border border-dashed border-artisan-clay bg-artisan-bone/40 p-6 text-sm text-muted-foreground md:flex-row md:items-center md:justify-between">
        <p>Start with the Shop page, then return here from the sidebar.</p>
        <Button asChild className="rounded-full bg-artisan-terracotta hover:bg-artisan-terracotta/90">
          <Link href="/vendor/profile/shop">Complete shop setup</Link>
        </Button>
      </div>
    </VendorPanel>
  );
}

export function VendorPageHeader({
  eyebrow,
  title,
  description,
  actions,
}: {
  eyebrow: string;
  title: string;
  description: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-col gap-4 rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-lg md:flex-row md:items-end md:justify-between">
      <div>
        <p className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">{eyebrow}</p>
        <h2 className="mt-2 text-4xl font-semibold text-artisan-sienna">{title}</h2>
        <p className="mt-2 max-w-3xl text-sm text-muted-foreground">{description}</p>
      </div>
      {actions ? <div className="shrink-0">{actions}</div> : null}
    </div>
  );
}

export function VendorMetric({
  label,
  value,
  helper,
}: {
  label: string;
  value: string;
  helper: string;
}) {
  return (
    <div className="rounded-3xl border border-artisan-clay/70 bg-white/90 p-5 shadow-sm">
      <p className="text-xs uppercase tracking-[0.2em] text-artisan-terracotta">{label}</p>
      <p className="mt-2 text-3xl font-semibold text-artisan-sienna">{value}</p>
      <p className="mt-2 text-sm text-muted-foreground">{helper}</p>
    </div>
  );
}

export function VendorPanel({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-[2rem] border border-artisan-clay/70 bg-white/90 p-6 shadow-sm">
      <div className="mb-5">
        <h3 className="text-2xl font-semibold text-artisan-sienna">{title}</h3>
        {description ? <p className="mt-1 text-sm text-muted-foreground">{description}</p> : null}
      </div>
      {children}
    </section>
  );
}
