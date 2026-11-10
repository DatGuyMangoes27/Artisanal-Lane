import { GetTheAppStrip } from "@/components/marketplace/get-the-app";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { PaymentSuccessContent } from "@/components/marketplace/payment-success-content";
import { PurchasePixel, RememberedPurchasePixel } from "@/components/marketplace/purchase-pixel";
import { summarisePurchase, type PurchaseOrderRow } from "@/lib/marketplace/purchase-summary";
import { createClient } from "@/lib/supabase/server";

type PaymentSuccessPageProps = {
  searchParams?: Promise<{ orderId?: string; group?: string }>;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The buyer's own orders for this checkout, for the Meta Purchase event. */
async function loadPurchase(orderId: string | null, groupId: string | null) {
  const id = orderId?.trim() ?? "";
  const group = groupId?.trim() ?? "";
  if (!UUID.test(id) && !UUID.test(group)) return null;
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return null;
    let query = supabase
      .from("orders")
      .select("id, status, total, shipping_cost, order_items(product_id, quantity)")
      .eq("buyer_id", user.id);
    query = UUID.test(group) ? query.eq("checkout_group_id", group) : query.eq("id", id);
    const { data } = await query;
    const summary = summarisePurchase((data ?? []) as PurchaseOrderRow[]);
    return summary ? { ...summary, eventId: UUID.test(group) ? group : id } : null;
  } catch {
    return null;
  }
}

export default async function PaymentSuccessPage({ searchParams }: PaymentSuccessPageProps) {
  const params = await searchParams;
  const purchase = await loadPurchase(params?.orderId ?? null, params?.group ?? null);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
        <PaymentSuccessContent orderId={params?.orderId ?? null} checkoutGroupId={params?.group ?? null} />
        <div className="mt-10">
          <GetTheAppStrip message="Track this order and chat to the maker in the Artisan Lane app." />
        </div>
        {purchase ? (
          <PurchasePixel
            eventId={purchase.eventId}
            value={purchase.value}
            contentIds={purchase.contentIds}
            numItems={purchase.numItems}
          />
        ) : (
          <RememberedPurchasePixel />
        )}
      </main>
    </div>
  );
}
