import type { Metadata } from "next";

import { LearningTutorialBrowser } from "@/components/marketplace/learning-tutorial-browser";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { getPublishedLearningResources } from "@/lib/learning";

export const metadata: Metadata = {
  title: "Tutorials | Artisan Lane",
  description:
    "Free app and website tutorials for selling, shopping, and managing an Artisan Lane shop.",
};

export default async function TutorialsPage() {
  const tutorials = await getPublishedLearningResources("tutorial");

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader activeItem="tutorials" />
      <main className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8 lg:py-14">
        <header className="max-w-3xl">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-artisan-terracotta">
            Help centre
          </p>
          <h1 className="mt-3 font-serif text-4xl font-bold text-foreground sm:text-5xl">
            Artisan Lane tutorials
          </h1>
          <p className="mt-4 text-base leading-7 text-muted-foreground">
            Step-by-step video help for the Artisan Lane app and website. Choose where you are
            working, then find the task you need.
          </p>
        </header>

        {tutorials.length > 0 ? (
          <LearningTutorialBrowser resources={tutorials} />
        ) : (
          <div className="mt-12 rounded-3xl border border-dashed border-artisan-clay bg-card p-12 text-center text-muted-foreground">
            New tutorials are on the way. Check back soon.
          </div>
        )}
      </main>
    </div>
  );
}
