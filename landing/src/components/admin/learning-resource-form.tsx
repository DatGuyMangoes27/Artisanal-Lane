"use client";

import { useActionState } from "react";

import { saveLearningResource } from "@/app/admin/actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { initialAdminActionState } from "@/lib/admin-action-state";
import type { AdminLearningResource } from "@/lib/admin-data";

const inputClass =
  "w-full rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta";

export function LearningResourceForm({
  resource,
}: {
  resource?: AdminLearningResource;
}) {
  const [state, formAction, pending] = useActionState(
    saveLearningResource,
    initialAdminActionState,
  );

  return (
    <form action={formAction} className="space-y-3">
      {resource ? <input name="resourceId" type="hidden" value={resource.id} /> : null}
      {resource?.thumbnail_url ? (
        <input name="existingThumbnailUrl" type="hidden" value={resource.thumbnail_url} />
      ) : null}

      <div className="grid gap-3 md:grid-cols-2">
        <label className="space-y-1">
          <span className="text-sm font-medium text-artisan-sienna">Type</span>
          <select className={inputClass} defaultValue={resource?.type ?? "article"} name="type">
            <option value="podcast">Podcast</option>
            <option value="video">Video tutorial</option>
            <option value="article">Article / guide</option>
          </select>
        </label>
        <label className="space-y-1">
          <span className="text-sm font-medium text-artisan-sienna">Sort order</span>
          <input
            className={inputClass}
            defaultValue={String(resource?.sort_order ?? 0)}
            name="sortOrder"
            inputMode="numeric"
            placeholder="0"
          />
        </label>
      </div>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">Title</span>
        <input className={inputClass} defaultValue={resource?.title ?? ""} name="title" required />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">Link (podcast / video / article URL)</span>
        <input
          className={inputClass}
          defaultValue={resource?.content_url ?? ""}
          name="contentUrl"
          type="url"
          placeholder="https://..."
          required
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">Description</span>
        <textarea
          className={`${inputClass} min-h-20`}
          defaultValue={resource?.description ?? ""}
          name="description"
          placeholder="Short summary shown on the learning page"
        />
      </label>

      <div className="grid gap-3 md:grid-cols-2">
        <label className="space-y-1">
          <span className="text-sm font-medium text-artisan-sienna">Author / host</span>
          <input
            className={inputClass}
            defaultValue={resource?.author ?? ""}
            name="author"
            placeholder="e.g. Artisan Lane"
          />
        </label>
        <label className="space-y-1">
          <span className="text-sm font-medium text-artisan-sienna">Duration</span>
          <input
            className={inputClass}
            defaultValue={resource?.duration_label ?? ""}
            name="durationLabel"
            placeholder="e.g. 32 min, 5 min read"
          />
        </label>
      </div>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">Thumbnail image</span>
        <input className={inputClass} name="thumbnail" type="file" accept="image/*" />
        {resource?.thumbnail_url ? (
          <span className="text-xs text-muted-foreground">
            Leave empty to keep the current thumbnail.
          </span>
        ) : null}
      </label>

      <div className="flex flex-wrap gap-5 pt-1">
        <label className="flex items-center gap-2 text-sm font-medium text-artisan-sienna">
          <input name="isPublished" type="checkbox" defaultChecked={resource?.is_published ?? true} />
          Published
        </label>
        <label className="flex items-center gap-2 text-sm font-medium text-artisan-sienna">
          <input name="isFeatured" type="checkbox" defaultChecked={resource?.is_featured ?? false} />
          Featured
        </label>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <Button
          className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
          disabled={pending}
          type="submit"
        >
          {pending ? "Saving..." : resource ? "Save changes" : "Add resource"}
        </Button>
        <AdminActionFeedback state={state} />
      </div>
    </form>
  );
}
