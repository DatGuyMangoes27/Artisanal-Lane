/// Deterministic, on-device tag suggestions — never AI. Ranks candidate
/// tags (typically a category's filter tags) by how well they match the
/// product title, falling back to words pulled straight from the title
/// when no candidates are supplied.
const _stopWords = {
  'the', 'and', 'for', 'with', 'from', 'your', 'this', 'that', 'a', 'an',
  'of', 'in', 'on', 'to', 'is', 'it', 'by', 'set', 'new', //
};

List<String> _titleWords(String title) => title
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.length > 2 && !_stopWords.contains(w))
    .toList(growable: false);

/// Returns up to [limit] suggested tags, excluding any already present in
/// [existingTags]. Order is deterministic: best match first, then
/// alphabetical.
List<String> suggestListingTags({
  required String title,
  String? category,
  List<String> existingTags = const [],
  List<String> candidateTags = const [],
  int limit = 8,
}) {
  final existing = existingTags.map((t) => t.toLowerCase()).toSet();
  final words = _titleWords(title);
  final categoryWords = category == null ? <String>[] : _titleWords(category);

  if (candidateTags.isNotEmpty) {
    final scored = <MapEntry<String, int>>[];
    for (final tag in candidateTags) {
      final normalized = tag.toLowerCase();
      if (existing.contains(normalized)) continue;
      var score = 0;
      for (final word in words) {
        if (normalized.contains(word) || word.contains(normalized)) score += 2;
      }
      for (final word in categoryWords) {
        if (normalized.contains(word) || word.contains(normalized)) score += 1;
      }
      scored.add(MapEntry(tag, score));
    }
    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      return byScore != 0 ? byScore : a.key.compareTo(b.key);
    });
    return scored.map((e) => e.key).take(limit).toList(growable: false);
  }

  final fromTitle = <String>[
    if (category != null && category.trim().isNotEmpty) category.trim(),
    for (final word in words) word[0].toUpperCase() + word.substring(1),
  ];
  final seen = <String>{};
  final result = <String>[];
  for (final tag in fromTitle) {
    final normalized = tag.toLowerCase();
    if (existing.contains(normalized) || seen.contains(normalized)) continue;
    seen.add(normalized);
    result.add(tag);
    if (result.length >= limit) break;
  }
  return result;
}
