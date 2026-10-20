import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { PaymentSuccessContent } from "@/components/marketplace/payment-success-content";

type PaymentSuccessPageProps = {
  searchParams?: Promise<{ orderId?: string; group?: string }>;
};

export default async function PaymentSuccessPage({ searchParams }: PaymentSuccessPageProps) {
  const params = await searchParams;

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
        <PaymentSuccessContent orderId={params?.orderId ?? null} checkoutGroupId={params?.group ?? null} />
      </main>
    </div>
  );
}
