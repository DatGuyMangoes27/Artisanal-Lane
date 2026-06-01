List<String> resolveTrendingSearchTerms({
  required List<String> configuredTerms,
  required List<String> fallbackTerms,
  int limit = 8,
}) {
  final source = configuredTerms.any((term) => term.trim().isNotEmpty)
      ? configuredTerms
      : fallbackTerms;
  final seen = <String>{};
  final resolved = <String>[];

  for (final term in source) {
    final clean = term.trim();
    if (clean.isEmpty) continue;
    final key = clean.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    resolved.add(clean);
    if (resolved.length >= limit) break;
  }

  return resolved;
}
