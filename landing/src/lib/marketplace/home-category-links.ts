import type { MarketplaceCategorySummary } from "./types";

// Mirrors the mobile app's home screen: every category from the database,
// in its seeded sort_order (the order getMarketplaceCategories returns).
export function buildHomeCategoryLinks(categories: MarketplaceCategorySummary[]) {
  const seenCategoryIds = new Set<string>();

  return categories.flatMap((category) => {
    if (seenCategoryIds.has(category.id)) {
      return [];
    }

    seenCategoryIds.add(category.id);

    return [{
      label: category.name,
      href: `/shop?category=${encodeURIComponent(category.id)}`,
    }];
  });
}
