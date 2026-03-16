"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  LayoutDashboard,
  LogOut,
  Package,
  Receipt,
  ShieldAlert,
  Store,
  Users,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/browser";

const navItems = [
  {
    href: "/admin",
    label: "Dashboard",
    icon: LayoutDashboard,
  },
  {
    href: "/admin/applications",
    label: "Applications",
    icon: Users,
  },
  {
    href: "/admin/products",
    label: "Products",
    icon: Package,
  },
  {
    href: "/admin/shops",
    label: "Shops",
    icon: Store,
  },
  {
    href: "/admin/orders",
    label: "Orders",
    icon: Receipt,
  },
  {
    href: "/admin/disputes",
    label: "Disputes",
    icon: ShieldAlert,
  },
];

type AdminShellProps = {
  children: React.ReactNode;
  displayName: string;
  email: string;
};

export function AdminShell({
  children,
  displayName,
  email,
}: AdminShellProps) {
  const pathname = usePathname();
  const router = useRouter();

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.replace("/admin/login");
    router.refresh();
  }

  return (
    <div className="min-h-screen bg-[linear-gradient(180deg,#fdf5ec_0%,#fffaf5_45%,#f7e4cc_100%)]">
      <div className="mx-auto flex min-h-screen max-w-7xl gap-6 px-4 py-6 sm:px-6 lg:px-8">
        <aside className="hidden w-72 shrink-0 rounded-3xl border border-artisan-clay/70 bg-white/85 p-5 shadow-xl backdrop-blur lg:flex lg:flex-col">
          <div className="mb-8">
            <p className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">
              Artisan Lane
            </p>
            <h1 className="mt-2 text-3xl font-semibold text-artisan-sienna">
              Admin
            </h1>
            <p className="mt-3 text-sm text-muted-foreground">
              Curate vendors, moderate listings, and manage platform operations.
            </p>
          </div>

          <nav className="space-y-2">
            {navItems.map((item) => {
              const Icon = item.icon;
              const isActive =
                pathname === item.href ||
                (item.href !== "/admin" && pathname.startsWith(item.href));

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium transition",
                    isActive
                      ? "bg-artisan-terracotta text-white shadow-lg"
                      : "text-artisan-sienna hover:bg-artisan-bone",
                  )}
                >
                  <Icon className="h-4 w-4" />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <div className="mt-auto rounded-2xl border border-artisan-clay bg-artisan-bone/60 p-4">
            <p className="text-sm font-semibold text-artisan-sienna">
              {displayName}
            </p>
            <p className="mt-1 text-xs text-muted-foreground">{email}</p>
            <Button
              className="mt-4 w-full bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
              onClick={handleSignOut}
              type="button"
            >
              <LogOut className="mr-2 h-4 w-4" />
              Sign Out
            </Button>
          </div>
        </aside>

        <div className="flex min-h-screen flex-1 flex-col">
          <header className="mb-4 rounded-3xl border border-artisan-clay/70 bg-white/80 px-5 py-4 shadow-lg backdrop-blur lg:hidden">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">
                  Artisan Lane
                </p>
                <h1 className="mt-1 text-2xl font-semibold text-artisan-sienna">
                  Admin
                </h1>
              </div>
              <Button
                className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
                onClick={handleSignOut}
                size="sm"
                type="button"
              >
                <LogOut className="mr-2 h-4 w-4" />
                Sign Out
              </Button>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              {navItems.map((item) => {
                const isActive =
                  pathname === item.href ||
                  (item.href !== "/admin" && pathname.startsWith(item.href));
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={cn(
                      "rounded-full px-3 py-2 text-xs font-medium transition",
                      isActive
                        ? "bg-artisan-terracotta text-white"
                        : "bg-artisan-bone text-artisan-sienna",
                    )}
                  >
                    {item.label}
                  </Link>
                );
              })}
            </div>
          </header>

          <main className="flex-1">{children}</main>
        </div>
      </div>
    </div>
  );
}
