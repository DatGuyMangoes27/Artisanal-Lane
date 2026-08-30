import { BadgeCheck, BookOpen, ExternalLink, Headphones, Megaphone, PlayCircle, ShieldCheck, Truck } from "lucide-react";

import { LearningVideoModal } from "@/components/marketplace/learning-video-modal";
import { VendorPageHeader, VendorPanel } from "@/components/vendor/vendor-shell";
import { getPublishedLearningResources, type LearningResource } from "@/lib/learning";

const resourceIcons = {
  article: BookOpen,
  podcast: Headphones,
  video: PlayCircle,
};

const subscriptionBenefits = [
  {
    title: "TradeSafe",
    description: "Secure marketplace payments and escrow support for eligible orders.",
    Icon: ShieldCheck,
  },
  {
    title: "Bob Go",
    description: "Integrated courier quotes, delivery booking, and tracking from your order workflow.",
    Icon: Truck,
  },
  {
    title: "Marketing",
    description: "Opportunities to be featured through Artisan Lane campaigns, content, and social channels.",
    Icon: Megaphone,
  },
  {
    title: "Curated platform",
    description: "Your shop appears in a screened South African handmade marketplace with artisan tools and support.",
    Icon: BadgeCheck,
  },
];

function LibraryResourceCard({ resource }: { resource: LearningResource }) {
  const Icon = resourceIcons[resource.type];
  const content = (
    <>
      <div className="relative aspect-video overflow-hidden bg-artisan-bone">
        {resource.thumbnailUrl ? (
          // Private vendor-library pages can safely display the public admin-uploaded thumbnail URL.
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={resource.thumbnailUrl}
            alt={resource.title}
            className="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
          />
        ) : (
          <div className="flex h-full items-center justify-center">
            <Icon className="h-11 w-11 text-artisan-terracotta/75" />
          </div>
        )}
        <span className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-black/60 px-3 py-1 text-xs font-semibold capitalize text-white">
          <Icon className="h-3.5 w-3.5" />
          {resource.type}
        </span>
      </div>
      <div className="flex flex-1 flex-col gap-2 p-5">
        <h3 className="text-lg font-semibold text-artisan-sienna">{resource.title}</h3>
        {resource.description ? (
          <p className="line-clamp-3 text-sm text-muted-foreground">{resource.description}</p>
        ) : null}
        <div className="mt-auto flex items-center justify-between gap-3 pt-3 text-xs text-muted-foreground">
          <span>{[resource.author, resource.durationLabel].filter(Boolean).join(" · ")}</span>
          <span className="flex items-center gap-1 font-semibold text-artisan-terracotta">
            {resource.type === "video" ? "Watch" : resource.type === "podcast" ? "Listen" : "Read"}
            <ExternalLink className="h-3.5 w-3.5" />
          </span>
        </div>
      </div>
    </>
  );
  const className =
    "group flex h-full flex-col overflow-hidden rounded-3xl border border-artisan-clay bg-white text-left shadow-sm transition hover:-translate-y-1 hover:shadow-md";

  if (resource.type === "video") {
    return (
      <LearningVideoModal
        title={resource.title}
        url={resource.contentUrl}
        thumbnailUrl={resource.thumbnailUrl}
        className={className}
      >
        {content}
      </LearningVideoModal>
    );
  }

  return (
    <a href={resource.contentUrl} target="_blank" rel="noopener noreferrer" className={className}>
      {content}
    </a>
  );
}

export default async function VendorLibraryPage() {
  const resources = await getPublishedLearningResources("library");

  return (
    <div className="space-y-6">
      <VendorPageHeader
        eyebrow="Artisan resources"
        title="Library"
        description="Business guidance, useful industry content, and clear information about your Artisan Lane membership."
      />

      <VendorPanel
        title="What your R349 monthly subscription gives you"
        description="Your subscription keeps your artisan shop and its connected marketplace tools active."
      >
        <div className="grid gap-4 md:grid-cols-2">
          {subscriptionBenefits.map(({ title, description, Icon }) => (
            <div key={title} className="flex gap-4 rounded-3xl border border-artisan-clay bg-artisan-bone/45 p-5">
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-artisan-terracotta text-white">
                <Icon className="h-5 w-5" />
              </span>
              <div>
                <h3 className="font-semibold text-artisan-sienna">{title}</h3>
                <p className="mt-1 text-sm leading-6 text-muted-foreground">{description}</p>
              </div>
            </div>
          ))}
        </div>
        <p className="mt-5 text-xs leading-5 text-muted-foreground">
          Courier, payment, escrow, and other order-specific charges are calculated separately where applicable.
        </p>
      </VendorPanel>

      <VendorPanel
        title="Business library"
        description="Pricing guidance, craft-industry inspiration, podcasts, articles, and videos selected for Artisan Lane makers."
      >
        {resources.length > 0 ? (
          <div className="grid gap-6 sm:grid-cols-2 xl:grid-cols-3">
            {resources.map((resource) => (
              <LibraryResourceCard key={resource.id} resource={resource} />
            ))}
          </div>
        ) : (
          <div className="rounded-3xl border border-dashed border-artisan-clay bg-artisan-bone/40 p-10 text-center text-sm text-muted-foreground">
            New library resources are on the way.
          </div>
        )}
      </VendorPanel>
    </div>
  );
}
