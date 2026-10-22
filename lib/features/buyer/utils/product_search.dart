import '../../../models/models.dart';

/// Relevance matching for buyer product search.
///
/// Matching is word based, never raw substring: a query word matches a
/// product word when the words are equal (ignoring simple plurals, so
/// "rings" finds "ring") or when the product word starts with the query word
/// (so a half-typed "neckla" finds "necklace"). A query word that only
/// appears *inside* another word ("rings" in "earrings" or "strings") does
/// not match.
///
/// Every query word must match somewhere. Each word scores by the best field
/// it matched in: title, then tags/category/subcategory, then shop name, then
/// description. Results are ordered by score, keeping the incoming order
/// (newest first from the server) for ties.
///
/// Mirrored by `public.search_buyer_products` (SQL) and
/// `landing/src/lib/marketplace/product-search.ts` (website) — keep the three
/// in step.

const _maxQueryWords = 8;

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Lowercased words of [text], split on anything that is not a letter or
/// digit.
List<String> searchWords(String? text) {
  if (text == null || text.isEmpty) return const [];
  return text
      .toLowerCase()
      .split(_nonWord)
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
}

/// Distinct words of a search query, capped so a pasted paragraph can't
/// blow up matching.
List<String> searchQueryWords(String query) =>
    searchWords(query).toSet().take(_maxQueryWords).toList(growable: false);

/// Naive English singular: "rings" → "ring", "boxes" → "box",
/// "accessories" → "accessory". Leaves "glass", "cactus", "iris" alone.
String singularSearchWord(String word) {
  if (word.length > 4 && word.endsWith('ies')) {
    return '${word.substring(0, word.length - 3)}y';
  }
  if (word.length > 4 &&
      (word.endsWith('sses') ||
          word.endsWith('xes') ||
          word.endsWith('ches') ||
          word.endsWith('shes') ||
          word.endsWith('zes'))) {
    return word.substring(0, word.length - 2);
  }
  if (word.length > 3 &&
      word.endsWith('s') &&
      !word.endsWith('ss') &&
      !word.endsWith('us') &&
      !word.endsWith('is')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

enum SearchWordMatch { none, prefix, exact }

/// How well [queryWord] matches the best of [words].
SearchWordMatch matchSearchWord(String queryWord, List<String> words) {
  final singularQuery = singularSearchWord(queryWord);
  var best = SearchWordMatch.none;
  for (final word in words) {
    if (word == queryWord || singularSearchWord(word) == singularQuery) {
      return SearchWordMatch.exact;
    }
    if (queryWord.length >= 2 && word.startsWith(queryWord)) {
      best = SearchWordMatch.prefix;
    }
  }
  return best;
}

int _fieldScore(SearchWordMatch match, int exact, int prefix) =>
    switch (match) {
      SearchWordMatch.exact => exact,
      SearchWordMatch.prefix => prefix,
      SearchWordMatch.none => 0,
    };

/// Relevance score of [product] for [query]; 0 means "not a match".
int productSearchScore(Product product, String query) =>
    _scoreWords(product, searchQueryWords(query));

int _scoreWords(Product product, List<String> queryWords) {
  if (queryWords.isEmpty) return 0;
  final title = searchWords(product.title);
  final meta = [
    for (final tag in product.tags) ...searchWords(tag),
    ...searchWords(product.categoryName),
    ...searchWords(product.subcategoryName),
  ];
  final shop = searchWords(product.shopName);
  final description = searchWords(product.description);

  var total = 0;
  for (final word in queryWords) {
    final best = [
      _fieldScore(matchSearchWord(word, title), 100, 80),
      _fieldScore(matchSearchWord(word, meta), 60, 50),
      _fieldScore(matchSearchWord(word, shop), 40, 30),
      _fieldScore(matchSearchWord(word, description), 20, 15),
    ].reduce((a, b) => a > b ? a : b);
    if (best == 0) return 0;
    total += best;
  }
  // Small nudge for titles that start with what was typed.
  final normalizedQuery = queryWords.join(' ');
  if (title.join(' ').startsWith(normalizedQuery)) total += 10;
  return total;
}

/// Keeps only products that match [query] and orders them by relevance,
/// preserving the incoming order for equal scores.
List<Product> rankProductSearch(List<Product> products, String query) {
  final queryWords = searchQueryWords(query);
  if (queryWords.isEmpty) return const [];
  final scored = <({Product product, int score, int index})>[];
  for (var i = 0; i < products.length; i++) {
    final score = _scoreWords(products[i], queryWords);
    if (score > 0) scored.add((product: products[i], score: score, index: i));
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return [for (final entry in scored) entry.product];
}
