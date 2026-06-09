import "server-only";

import { createClient } from "@/lib/supabase/server";

export type LearningResourceType = "podcast" | "video" | "article";

export type LearningResource = {
  id: string;
  type: LearningResourceType;
  title: string;
  description: string | null;
  contentUrl: string;
  thumbnailUrl: string | null;
  author: string | null;
  durationLabel: string | null;
  isPublished: boolean;
  isFeatured: boolean;
  sortOrder: number;
  createdAt: string;
};

type LearningResourceRow = {
  id: string;
  type: string | null;
  title: string;
  description: string | null;
  content_url: string;
  thumbnail_url: string | null;
  author: string | null;
  duration_label: string | null;
  is_published: boolean | null;
  is_featured: boolean | null;
  sort_order: number | null;
  created_at: string;
};

export function normalizeLearningType(value: unknown): LearningResourceType {
  return value === "podcast" || value === "video" ? value : "article";
}

export function mapLearningResource(row: LearningResourceRow): LearningResource {
  return {
    id: row.id,
    type: normalizeLearningType(row.type),
    title: row.title,
    description: row.description,
    contentUrl: row.content_url,
    thumbnailUrl: row.thumbnail_url,
    author: row.author,
    durationLabel: row.duration_label,
    isPublished: row.is_published ?? true,
    isFeatured: row.is_featured ?? false,
    sortOrder: row.sort_order ?? 0,
    createdAt: row.created_at,
  };
}

const learningSelect =
  "id, type, title, description, content_url, thumbnail_url, author, duration_label, is_published, is_featured, sort_order, created_at";

export async function getPublishedLearningResources(): Promise<LearningResource[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("learning_resources")
    .select(learningSelect)
    .eq("is_published", true)
    .order("is_featured", { ascending: false })
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: false });

  if (error || !data) {
    return [];
  }

  return data.map((row) => mapLearningResource(row as LearningResourceRow));
}
