"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BarChart3,
  CreditCard,
  Home,
  Inbox,
  Newspaper,
  Package,
  PackageOpen,
  ReceiptText,
  Settings,
  Store,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import { VendorLogoutButton } from "@/components/vendor/vendor-logout-button";
import { cn } from "@/lib/utils";

const navSections = [
  {
    label: "Workspace",
    items: [
      { href: "/vendor", label: "Dashboard", icon: Home },
      { href: "/vendor/products", label: "Products", icon: Package },
      { href: "/vendor/orders", label: "Orders", icon: ReceiptText },
      { href: "/vendor/messages", label: "Messages", icon: Inbox },
      { href: "/vendor/earnings", label: "Earnings", icon: BarChart3 },
    ],
  },
  {
    label: "Profile",
    items: [
      { href: "/vendor/profile/shop", label: "Shop", icon: Store },
      { href: "/vendor/profile/posts", label: "Posts", icon: Newspaper },
    ],
  },
  {
    label: "Money and fulfilment",
    items: [
      { href: "/vendor/profile/payouts", label: "Payouts", icon: CreditCard },
      { href: "/vendor/profile/subscription", label: "Subscription", icon: Settings },
      { href: "/vendor/profile/stationery", label: "Stationery", icon: PackageOpen },
    ],
  },
];

export function VendorSidebarNav() {
  const pathname = usePathname();

  return (
    <nav className="mt-4 grid gap-5">
      {navSections.map((section) => (
        <div key={section.label}>
          <p className="px-3 text-[0.65rem] font-semibold uppercase tracking-[0.22em] text-muted-foreground">
            {section.label}
          </p>
          <div className="mt-2 grid gap-1">
            {section.items.map((item) => {
              const Icon = item.icon;
              const active =
                pathname === item.href ||
                (item.href !== "/vendor" && pathname.startsWith(item.href));

              return (
                <Button
                  key={item.href}
                  asChild
                  className={cn(
                    "justify-start rounded-2xl",
                    active
                      ? "bg-artisan-terracotta text-white hover:bg-artisan-terracotta/90"
                      : "text-artisan-sienna",
                  )}
                  variant={active ? "default" : "ghost"}
                >
                  <Link href={item.href}>
                    <Icon className="h-4 w-4" />
                    {item.label}
                  </Link>
                </Button>
              );
            })}
            {section.label === "Money and fulfilment" ? (
              <VendorLogoutButton
                variant="outline"
                className="mt-1 w-full border-artisan-clay bg-white text-artisan-sienna shadow-sm hover:border-artisan-terracotta hover:text-artisan-terracotta"
              />
            ) : null}
          </div>
        </div>
      ))}
    </nav>
  );
}
