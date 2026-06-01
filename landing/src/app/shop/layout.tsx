import type { ReactNode } from "react";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";

export default function ShopLayout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader activeItem="shop" />
      {children}
    </div>
  );
}
