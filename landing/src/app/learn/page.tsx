import type { Metadata } from "next";
import { Headphones, PlayCircle, BookOpen, ArrowUpRight } from "lucide-react";

import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { getPublishedLearningResources, type LearningResource, type LearningResourceType } from "@/lib/learning";
import { getLearningEmbedUrl } from "@/lib/learning-embed";

export const metadata: Metadata = {
  title: "Learn | Artisan Lane",
  description:
    "Podcasts, video tutorials, and business-learning guides curated for Artisan Lane makers and the craft community.",
};

const typeMeta: Record<
  LearningResourceType,
  { label: string; action: string; Icon: typeof Headphones }
> = {
  podcast: { label: "Podcast", action: "Listen", Icon: Headphones },
  video: { label: "Video", action: "Watch", Icon: PlayCircle },
  article: { label: "Article", action: "Read", Icon: BookOpen },
};

const sectionOrder: { type: LearningResourceType; title: string; blurb: string }[] = [
  { type: "podcast", title: "Podcasts", blurb: "Conversations and stories from the craft world." },
  { type: "video", title: "Video tutorials", blurb: "Watch and learn new skills and techniques." },
  { type: "article", title: "Articles & guides", blurb: "Business-learning reads to grow your craft." },
];

function ResourceCard({ resource }: { resource: LearningResource }) {
  const meta = typeMeta[resource.type];
  const { Icon } = meta;
  return (
    <a
      href={resource.contentUrl}
      target="_blank"
      rel="noopener noreferrer"
      className="group flex flex-col overflow-hidden rounded-3xl border border-artisan-clay bg-card shadow-sm transition hover:-translate-y-1 hover:shadow-md"
    >
      <div className="relative aspect-video overflow-hidden bg-secondary">
        {resource.thumbnailUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={resource.thumbnailUrl}
            alt={resource.title}
            className="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-artisan-bone">
            <Icon className="h-10 w-10 text-artisan-terracotta/70" />
          </div>
        )}
        <span className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-black/55 px-3 py-1 text-xs font-semibold text-white">
          <Icon className="h-3.5 w-3.5" />
          {meta.label}
        </span>
      </div>
      <div className="flex flex-1 flex-col gap-2 p-5">
        <h3 className="text-lg font-semibold text-artisan-sienna">{resource.title}</h3>
        {resource.description ? (
          <p className="line-clamp-3 text-sm text-muted-foreground">{resource.description}</p>
        ) : null}
        <div className="mt-auto flex items-center justify-between pt-2">
          <span className="text-xs text-muted-foreground">
            {[resource.author, resource.durationLabel].filter(Boolean).join(" \u00b7 ")}
          </span>
          <span className="flex items-center gap-1 text-sm font-semibold text-artisan-terracotta">
            {meta.action}
            <ArrowUpRight className="h-4 w-4 transition group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
          </span>
        </div>
      </div>
    </a>
  );
}

function FeaturedResource({ resource }: { resource: LearningResource }) {
  const meta = typeMeta[resource.type];
  const embedUrl = getLearningEmbedUrl(resource.contentUrl);

  return (
    <div className="grid gap-6 overflow-hidden rounded-[2rem] border border-artisan-clay bg-card p-5 shadow-sm lg:grid-cols-2 lg:p-6">
      <div className="relative overflow-hidden rounded-2xl bg-secondary">
        {embedUrl ? (
          <iframe
            src={embedUrl}
            title={resource.title}
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
            className="aspect-video h-full w-full"
          />
        ) : resource.thumbnailUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={resource.thumbnailUrl}
            alt={resource.title}
            className="aspect-video h-full w-full object-cover"
          />
        ) : (
          <div className="flex aspect-video items-center justify-center bg-artisan-bone">
            <meta.Icon className="h-12 w-12 text-artisan-terracotta/70" />
          </div>
        )}
      </div>
      <div className="flex flex-col justify-center gap-3">
        <span className="flex w-fit items-center gap-1.5 rounded-full bg-artisan-terracotta/15 px-3 py-1 text-xs font-semibold text-artisan-terracotta">
          <meta.Icon className="h-3.5 w-3.5" />
          Featured {meta.label.toLowerCase()}
        </span>
        <h3 className="text-2xl font-semibold text-artisan-sienna">{resource.title}</h3>
        {resource.description ? (
          <p className="text-sm text-muted-foreground">{resource.description}</p>
        ) : null}
        <span className="text-xs text-muted-foreground">
          {[resource.author, resource.durationLabel].filter(Boolean).join(" \u00b7 ")}
        </span>
        <a
          href={resource.contentUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-1 flex w-fit items-center gap-1.5 rounded-full bg-artisan-terracotta px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-artisan-terracotta/90"
        >
          {meta.action}
          <ArrowUpRight className="h-4 w-4" />
        </a>
      </div>
    </div>
  );
}

export default async function LearnPage() {
  const resources = await getPublishedLearningResources();
  const featured = resources.filter((item) => item.isFeatured).slice(0, 2);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader activeItem="learn" />
      <main className="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8 lg:py-14">
        <header className="max-w-2xl">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-artisan-terracotta">
            Artisan Lane
          </p>
          <h1 className="mt-3 font-serif text-4xl font-bold text-foreground sm:text-5xl">
            Learn &amp; grow your craft
          </h1>
          <p className="mt-4 text-base text-muted-foreground">
            Podcasts, video tutorials, and business-learning guides hand-picked to help our makers and
            community build thriving creative businesses.
          </p>
        </header>

        {resources.length === 0 ? (
          <div className="mt-12 rounded-3xl border border-dashed border-artisan-clay bg-card p-12 text-center text-muted-foreground">
            New learning content is on the way. Check back soon.
          </div>
        ) : null}

        {featured.length > 0 ? (
          <section className="mt-10 space-y-6">
            {featured.map((resource) => (
              <FeaturedResource key={resource.id} resource={resource} />
            ))}
          </section>
        ) : null}

        {sectionOrder.map(({ type, title, blurb }) => {
          const items = resources.filter((resource) => resource.type === type);
          if (items.length === 0) return null;
          return (
            <section key={type} className="mt-14">
              <div className="flex items-end justify-between gap-4">
                <div>
                  <h2 className="text-2xl font-semibold text-artisan-sienna">{title}</h2>
                  <p className="mt-1 text-sm text-muted-foreground">{blurb}</p>
                </div>
              </div>
              <div className="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                {items.map((resource) => (
                  <ResourceCard key={resource.id} resource={resource} />
                ))}
              </div>
            </section>
          );
        })}
      </main>
    </div>
  );
}
