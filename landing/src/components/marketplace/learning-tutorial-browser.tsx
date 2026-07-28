"use client";

import { useMemo, useState } from "react";
import {
  ArrowUpRight,
  Boxes,
  CircleDollarSign,
  LayoutGrid,
  Monitor,
  PlayCircle,
  Settings,
  Smartphone,
  Sparkles,
} from "lucide-react";

import { LearningVideoModal } from "@/components/marketplace/learning-video-modal";
import {
  getTutorialPlatform,
  getTutorialSection,
  type TutorialPlatform,
  type TutorialSection,
} from "@/lib/learning-tutorials";

type TutorialResource = {
  id: string;
  title: string;
  description: string | null;
  contentUrl: string;
  thumbnailUrl: string | null;
  author: string | null;
  durationLabel: string | null;
  sortOrder: number;
};

const platformTabs: {
  id: TutorialPlatform;
  label: string;
  description: string;
  Icon: typeof Smartphone;
}[] = [
  {
    id: "app",
    label: "App",
    description: "Tutorials for the Artisan Lane mobile app",
    Icon: Smartphone,
  },
  {
    id: "website",
    label: "Website",
    description: "Tutorials for the Artisan Lane website",
    Icon: Monitor,
  },
];

const sectionTabs: {
  id: TutorialSection;
  label: string;
  Icon: typeof LayoutGrid;
}[] = [
  { id: "all", label: "All tutorials", Icon: LayoutGrid },
  { id: "getting-started", label: "Getting started", Icon: Sparkles },
  { id: "products", label: "Products", Icon: Boxes },
  { id: "orders", label: "Orders & earnings", Icon: CircleDollarSign },
  { id: "shop-management", label: "Shop management", Icon: Settings },
];

function displayTitle(resource: TutorialResource) {
  return resource.title.replace(/^Website:\s*/, "");
}

function TutorialCard({
  resource,
  platform,
}: {
  resource: TutorialResource;
  platform: TutorialPlatform;
}) {
  const title = displayTitle(resource);

  return (
    <LearningVideoModal
      title={`${platform === "website" ? "Website" : "App"}: ${title}`}
      url={resource.contentUrl}
      thumbnailUrl={resource.thumbnailUrl}
      className="group flex flex-col overflow-hidden rounded-3xl border border-artisan-clay bg-card shadow-sm transition hover:-translate-y-1 hover:shadow-md"
    >
      <div className="relative aspect-video overflow-hidden bg-secondary">
        {resource.thumbnailUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={resource.thumbnailUrl}
            alt={title}
            className="h-full w-full object-cover transition duration-300 group-hover:scale-[1.03]"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-artisan-bone">
            <PlayCircle className="h-10 w-10 text-artisan-terracotta/70" />
          </div>
        )}
        <span className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-black/60 px-3 py-1 text-xs font-semibold text-white">
          {platform === "website" ? (
            <Monitor className="h-3.5 w-3.5" />
          ) : (
            <Smartphone className="h-3.5 w-3.5" />
          )}
          {platform === "website" ? "Website" : "App"}
        </span>
      </div>
      <div className="flex flex-1 flex-col gap-2 p-5">
        <h3 className="text-lg font-semibold text-artisan-sienna">{title}</h3>
        {resource.description ? (
          <p className="line-clamp-3 text-sm text-muted-foreground">{resource.description}</p>
        ) : null}
        <div className="mt-auto flex items-center justify-between gap-4 pt-2">
          <span className="text-xs text-muted-foreground">
            {[resource.author, resource.durationLabel].filter(Boolean).join(" \u00b7 ")}
          </span>
          <span className="flex shrink-0 items-center gap-1 text-sm font-semibold text-artisan-terracotta">
            Watch
            <ArrowUpRight className="h-4 w-4 transition group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
          </span>
        </div>
      </div>
    </LearningVideoModal>
  );
}

export function LearningTutorialBrowser({
  resources,
}: {
  resources: TutorialResource[];
}) {
  const [platform, setPlatform] = useState<TutorialPlatform>("app");
  const [section, setSection] = useState<TutorialSection>("all");

  const platformResources = useMemo(
    () => resources.filter((resource) => getTutorialPlatform(resource) === platform),
    [platform, resources],
  );
  const visibleResources = useMemo(
    () =>
      section === "all"
        ? platformResources
        : platformResources.filter(
            (resource) => getTutorialSection(resource.sortOrder) === section,
          ),
    [platformResources, section],
  );

  const activePlatform = platformTabs.find((item) => item.id === platform)!;

  return (
    <section className="mt-14" aria-labelledby="video-tutorials-heading">
      <div>
        <h2 id="video-tutorials-heading" className="text-2xl font-semibold text-artisan-sienna">
          Video tutorials
        </h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Choose where you are working, then jump straight to the help you need.
        </p>
      </div>

      <div
        role="tablist"
        aria-label="Tutorial platform"
        className="mt-6 grid gap-3 sm:grid-cols-2"
      >
        {platformTabs.map(({ id, label, description, Icon }) => {
          const selected = platform === id;
          const count = resources.filter(
            (resource) => getTutorialPlatform(resource) === id,
          ).length;
          return (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={selected}
              aria-controls="tutorial-tab-panel"
              onClick={() => {
                setPlatform(id);
                setSection("all");
              }}
              className={`flex items-center gap-4 rounded-2xl border p-4 text-left transition ${
                selected
                  ? "border-artisan-terracotta bg-artisan-terracotta text-white shadow-sm"
                  : "border-artisan-clay bg-card text-artisan-sienna hover:border-artisan-terracotta/60"
              }`}
            >
              <span
                className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-full ${
                  selected ? "bg-white/15" : "bg-artisan-bone"
                }`}
              >
                <Icon className="h-5 w-5" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="flex items-center justify-between gap-3">
                  <span className="font-semibold">{label}</span>
                  <span
                    className={`rounded-full px-2.5 py-1 text-xs font-semibold ${
                      selected ? "bg-white/15" : "bg-artisan-bone text-artisan-terracotta"
                    }`}
                  >
                    {count}
                  </span>
                </span>
                <span
                  className={`mt-1 block text-xs ${
                    selected ? "text-white/80" : "text-muted-foreground"
                  }`}
                >
                  {description}
                </span>
              </span>
            </button>
          );
        })}
      </div>

      <div
        role="tablist"
        aria-label={`${activePlatform.label} tutorial sections`}
        className="mt-5 flex gap-2 overflow-x-auto pb-2"
      >
        {sectionTabs.map(({ id, label, Icon }) => {
          const selected = section === id;
          const count =
            id === "all"
              ? platformResources.length
              : platformResources.filter(
                  (resource) => getTutorialSection(resource.sortOrder) === id,
                ).length;
          return (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={selected}
              aria-controls="tutorial-tab-panel"
              onClick={() => setSection(id)}
              className={`flex shrink-0 items-center gap-2 rounded-full border px-4 py-2 text-sm font-semibold transition ${
                selected
                  ? "border-artisan-sienna bg-artisan-sienna text-white"
                  : "border-artisan-clay bg-card text-artisan-sienna hover:border-artisan-sienna/50"
              }`}
            >
              <Icon className="h-4 w-4" />
              {label}
              <span className={selected ? "text-white/70" : "text-muted-foreground"}>
                {count}
              </span>
            </button>
          );
        })}
      </div>

      <div
        id="tutorial-tab-panel"
        role="tabpanel"
        aria-label={`${activePlatform.label} tutorials`}
        className="mt-4"
      >
        <div className="mb-5 flex items-center gap-2 text-sm text-muted-foreground">
          <activePlatform.Icon className="h-4 w-4 text-artisan-terracotta" />
          <span>
            Showing {visibleResources.length} {activePlatform.label.toLowerCase()} tutorial
            {visibleResources.length === 1 ? "" : "s"}
          </span>
        </div>

        {visibleResources.length > 0 ? (
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {visibleResources.map((resource) => (
              <TutorialCard key={resource.id} resource={resource} platform={platform} />
            ))}
          </div>
        ) : (
          <div className="rounded-3xl border border-dashed border-artisan-clay bg-card p-10 text-center text-sm text-muted-foreground">
            No tutorials are available in this section yet.
          </div>
        )}
      </div>
    </section>
  );
}
