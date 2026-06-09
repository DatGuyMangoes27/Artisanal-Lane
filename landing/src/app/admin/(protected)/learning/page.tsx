import { AdminActionButtonForm } from "@/components/admin/admin-action-button-form";
import { AdminPageHeader, PanelCard } from "@/components/admin/admin-ui";
import { LearningResourceForm } from "@/components/admin/learning-resource-form";
import { deleteLearningResource } from "@/app/admin/actions";
import { listLearningResources } from "@/lib/admin-data";

const typeLabels: Record<string, string> = {
  podcast: "Podcast",
  video: "Video",
  article: "Article",
};

export default async function AdminLearningPage() {
  const resources = await listLearningResources();

  return (
    <>
      <AdminPageHeader
        eyebrow="Website content"
        title="Learning Hub"
        description="Curate podcasts, video tutorials, and articles shown to everyone on the public /learn page."
      />

      <PanelCard
        title="Add a resource"
        description="Paste a podcast, video, or article link and upload a thumbnail. Published items appear on the website immediately."
      >
        <LearningResourceForm />
      </PanelCard>

      <PanelCard
        title={`Published & draft resources (${resources.length})`}
        description="Edit, feature, hide, or remove existing learning content."
      >
        <div className="space-y-4">
          {resources.length === 0 ? (
            <div className="rounded-3xl border border-dashed border-artisan-clay bg-white p-8 text-sm text-muted-foreground">
              No learning resources yet. Add your first one above.
            </div>
          ) : null}

          {resources.map((resource) => (
            <div key={resource.id} className="rounded-3xl border border-artisan-clay bg-white p-5">
              <div className="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
                <div className="flex gap-4">
                  {resource.thumbnail_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={resource.thumbnail_url}
                      alt={resource.title}
                      className="h-20 w-20 shrink-0 rounded-2xl object-cover"
                    />
                  ) : (
                    <div className="flex h-20 w-20 shrink-0 items-center justify-center rounded-2xl bg-artisan-bone text-xs text-muted-foreground">
                      No image
                    </div>
                  )}
                  <div className="space-y-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="rounded-full bg-artisan-bone px-3 py-0.5 text-xs font-semibold text-artisan-sienna">
                        {typeLabels[resource.type] ?? resource.type}
                      </span>
                      {resource.is_featured ? (
                        <span className="rounded-full bg-artisan-terracotta/15 px-3 py-0.5 text-xs font-semibold text-artisan-terracotta">
                          Featured
                        </span>
                      ) : null}
                      {!resource.is_published ? (
                        <span className="rounded-full bg-muted px-3 py-0.5 text-xs font-semibold text-muted-foreground">
                          Hidden
                        </span>
                      ) : null}
                    </div>
                    <h3 className="text-lg font-semibold text-artisan-sienna">{resource.title}</h3>
                    {resource.author || resource.duration_label ? (
                      <p className="text-xs text-muted-foreground">
                        {[resource.author, resource.duration_label].filter(Boolean).join(" \u00b7 ")}
                      </p>
                    ) : null}
                    <a
                      href={resource.content_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block max-w-md truncate text-xs text-artisan-terracotta underline"
                    >
                      {resource.content_url}
                    </a>
                  </div>
                </div>

                <AdminActionButtonForm
                  action={deleteLearningResource}
                  hiddenFields={[{ name: "resourceId", value: resource.id }]}
                  idleContent="Delete"
                  pendingLabel="Deleting..."
                  buttonClassName="bg-red-600 text-white hover:bg-red-600/90"
                  confirmMessage="Delete this learning resource? This cannot be undone."
                />
              </div>

              <details className="mt-4">
                <summary className="cursor-pointer text-sm font-medium text-artisan-terracotta">
                  Edit
                </summary>
                <div className="mt-4 border-t border-artisan-clay/60 pt-4">
                  <LearningResourceForm resource={resource} />
                </div>
              </details>
            </div>
          ))}
        </div>
      </PanelCard>
    </>
  );
}
