export function resolveTrendingSearchTerms({
  configuredTerms,
  fallbackTerms,
  limit = 8,
}: {
  configuredTerms: string[];
  fallbackTerms: string[];
  limit?: number;
}) {
  const source = configuredTerms.some((term) => term.trim().length > 0)
    ? configuredTerms
    : fallbackTerms;
  const seen = new Set<string>();
  const resolved: string[] = [];

  for (const term of source) {
    const clean = term.trim();
    const key = clean.toLowerCase();
    if (!clean || seen.has(key)) {
      continue;
    }
    seen.add(key);
    resolved.push(clean);
    if (resolved.length >= limit) {
      break;
    }
  }

  return resolved;
}
