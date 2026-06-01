import type { MarketplaceCategorySummary } from "./types";

const preferredCategorySlugs = [
  "art-design",
  "clothing",
  "beauty",
  "self-care",
  "jewellery",
  "home-living",
  "home",
  "baby-kids",
];

function normalizeSlug(category: MarketplaceCategorySummary) {
  return category.slug ?? category.name.toLowerCase().replaceAll(/\s*&\s*|\s+/g, "-");
}

export function buildHomeCategoryLinks(categories: MarketplaceCategorySummary[]) {
  const categoriesBySlug = new Map(categories.map((category) => [normalizeSlug(category), category]));
  const seenCategoryIds = new Set<string>();

  return preferredCategorySlugs.flatMap((slug) => {
    const category = categoriesBySlug.get(slug);

    if (!category || seenCategoryIds.has(category.id)) {
      return [];
    }

    seenCategoryIds.add(category.id);

    return [{
      label: category.name,
      href: `/shop?category=${encodeURIComponent(category.id)}`,
    }];
  });
}
