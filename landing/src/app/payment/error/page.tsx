import { PaymentResultActions } from "@/components/marketplace/payment-result-actions";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { paymentResultStatusCopy } from "@/lib/marketplace/payment-results";

type PaymentErrorPageProps = {
  searchParams?: Promise<{ orderId?: string }>;
};

export default async function PaymentErrorPage({ searchParams }: PaymentErrorPageProps) {
  const params = await searchParams;
  const copy = paymentResultStatusCopy("error");

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          {copy.eyebrow}
        </p>
        <h1 className="mt-4 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
          {copy.title}
        </h1>
        <p className="mt-4 leading-7 text-muted-foreground">
          {copy.body}
        </p>
        <PaymentResultActions
          fallbackHref={copy.primaryActionHref}
          fallbackLabel={copy.primaryActionLabel}
          orderId={params?.orderId}
        />
      </main>
    </div>
  );
}
