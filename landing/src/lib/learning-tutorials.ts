export type TutorialPlatform = "app" | "website";
export type TutorialSection =
  | "all"
  | "getting-started"
  | "products"
  | "orders"
  | "shop-management";

type TutorialIdentity = {
  title: string;
  author: string | null;
  contentUrl: string;
};

export function getTutorialPlatform(resource: TutorialIdentity): TutorialPlatform {
  if (
    resource.title.startsWith("Website:") ||
    resource.author?.toLowerCase().includes("web") ||
    resource.contentUrl.includes("/web-landscape/")
  ) {
    return "website";
  }
  return "app";
}

export function getTutorialSection(
  sortOrder: number,
): Exclude<TutorialSection, "all"> {
  const tutorialNumber = sortOrder >= 101 ? sortOrder - 100 : sortOrder;

  if (tutorialNumber >= 1 && tutorialNumber <= 6) {
    return "getting-started";
  }
  if ([7, 8, 9, 21, 23].includes(tutorialNumber)) {
    return "products";
  }
  if (tutorialNumber === 10 || (tutorialNumber >= 13 && tutorialNumber <= 20)) {
    return "orders";
  }
  return "shop-management";
}
