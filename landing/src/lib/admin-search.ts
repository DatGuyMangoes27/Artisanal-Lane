function sanitizePostgrestSearch(value: string | undefined) {
  return value?.trim().replace(/[,()%]/g, " ").replace(/\s+/g, " ").trim() ?? "";
}

export function getPostgrestSearchTokens(value: string | undefined) {
  const fullTerm = sanitizePostgrestSearch(value);
  if (!fullTerm) return [];

  const ignoredWords = new Set(["and", "by", "for", "of", "the"]);
  const tokens = fullTerm
    .split(" ")
    .map((token) => token.toLowerCase())
    .filter((token) => token.length >= 3 && !ignoredWords.has(token))
    .map((token) => token.endsWith("s") ? token.slice(0, -1) : token);

  return Array.from(new Set(tokens)).filter((term) => term.length >= 2);
}
