import 'dart:math';

import '../../../models/product.dart';
import 'discover_taste.dart';
import 'discovery_preferences.dart';

/// Which "round" the cards currently on the Discover deck come from. The
/// buyer's choices are dominant: rounds run strictly in this order and a
/// later round only starts once every piece of the earlier ones is reviewed.
enum DiscoverDeckMode {
  /// Undecided pieces that match the buyer's choices: within their budget
  /// and, when they picked categories, ONLY those categories. Ordered by
  /// what their swipes and saves say they like. The normal deck.
  fresh,

  /// Every piece in the chosen categories has been reviewed (and there are
  /// no more pages to load), so the deck continues with undecided pieces in
  /// the budget from other categories. Only used when categories are chosen.
  otherCategories,

  /// Everything in budget has been reviewed (and there are no more pages to
  /// load), so the deck keeps going with undecided pieces above the budget,
  /// chosen categories first.
  beyondBudget,

  /// Every loaded piece has been reviewed, so the deck recycles previously
  /// reviewed pieces in a fresh order (preferred categories first). Each
  /// pass through the pool is a new "round" with a new shuffle.
  recycled,

  /// There are genuinely no products to show at all.
  empty,
}

class DiscoverDeck {
  const DiscoverDeck({
    required this.mode,
    required this.items,
    required this.total,
    required this.reviewed,
  });

  final DiscoverDeckMode mode;

  /// Cards in display order; the first is the top card.
  final List<Product> items;

  /// Number of pieces in the current round (for the "n of total" counter).
  final int total;

  /// How many pieces of the current round are already behind the buyer.
  final int reviewed;

  bool get isEmpty => items.isEmpty;

  /// 1-based position of the top card within the current round, for the
  /// "n of total" counter. Goes down when a swipe is undone.
  int get position => total == 0 ? 0 : (reviewed + 1).clamp(1, total);
}

/// Builds the Discover deck so the buyer's choices clearly lead and it never
/// dead-ends while real products exist.
///
/// 1. [DiscoverDeckMode.fresh]: undecided pieces within the budget and, when
///    categories are chosen, only in those categories, ranked by [taste]
///    (built from the buyer's loves, saves and skips when not given).
/// 2. When those run out and [canLoadMore] is true, returns an empty fresh
///    deck: the caller should fetch the next page, so the chosen categories
///    are shown exhaustively before anything else.
/// 3. [DiscoverDeckMode.otherCategories]: undecided pieces in the budget
///    from the categories that weren't chosen (only when some were).
/// 4. [DiscoverDeckMode.beyondBudget]: undecided pieces over the budget,
///    chosen categories first.
/// 5. [DiscoverDeckMode.recycled]: already-reviewed pieces (in budget when
///    there are any, otherwise all of them) in a shuffled order that changes
///    every round. [recycleCursor] counts the cards swiped while recycling;
///    it wraps into the next round automatically, so the deck is endless.
/// 6. [DiscoverDeckMode.empty] only when [products] is empty.
///
/// [DiscoverDeck.total] and [DiscoverDeck.reviewed] always describe the
/// current round only.
DiscoverDeck buildDiscoverDeck(
  List<Product> products,
  DiscoveryPreferences preferences, {
  bool canLoadMore = false,
  int recycleCursor = 0,
  DiscoverTaste? taste,
}) {
  final profile = taste ?? discoverTasteFor(products, preferences);
  final chosen = preferences.categoryIds;
  bool decided(Product p) =>
      preferences.likedProductIds.contains(p.id) ||
      preferences.skippedProductIds.contains(p.id);
  bool inBudget(Product p) => _inBudget(p, preferences);
  bool inChosen(Product p) => chosen.contains(p.categoryId);

  DiscoverDeck round(
    DiscoverDeckMode mode,
    bool Function(Product) belongs, {
    bool chosenFirst = false,
  }) {
    final members = products.where(belongs).toList(growable: false);
    final items = rankDiscoverRound(
      members.where((p) => !decided(p)),
      profile,
      chosenFirst: chosenFirst ? chosen : const <String>{},
    );
    return DiscoverDeck(
      mode: mode,
      items: items,
      total: members.length,
      reviewed: members.length - items.length,
    );
  }

  final fresh = round(
    DiscoverDeckMode.fresh,
    (p) => inBudget(p) && (chosen.isEmpty || inChosen(p)),
  );
  if (!fresh.isEmpty || canLoadMore) return fresh;
  if (products.isEmpty) {
    return const DiscoverDeck(
      mode: DiscoverDeckMode.empty,
      items: [],
      total: 0,
      reviewed: 0,
    );
  }

  if (chosen.isNotEmpty) {
    final others = round(
      DiscoverDeckMode.otherCategories,
      (p) => inBudget(p) && !inChosen(p),
    );
    if (!others.isEmpty) return others;
  }

  final beyond = round(
    DiscoverDeckMode.beyondBudget,
    (p) => !inBudget(p),
    chosenFirst: true,
  );
  if (!beyond.isEmpty) return beyond;

  final reviewed = products.where(decided).toList();
  final inBudgetReviewed = reviewed.where(inBudget).toList();
  final pool = inBudgetReviewed.isNotEmpty ? inBudgetReviewed : reviewed;
  final cursor = max(0, recycleCursor);
  final recycleRound = cursor ~/ pool.length;
  final offset = cursor % pool.length;
  final thisRound = recycleOrder(pool, preferences, recycleRound);
  // Append the next round so the peeking "next" card is never blank.
  final items = [
    ...thisRound.sublist(offset),
    ...recycleOrder(pool, preferences, recycleRound + 1),
  ];
  return DiscoverDeck(
    mode: DiscoverDeckMode.recycled,
    items: items,
    total: pool.length,
    reviewed: offset,
  );
}

/// Orders one round of undecided pieces: [chosenFirst] categories lead,
/// then the strongest [taste] match, then featured pieces, then newest.
/// Ties fall back to the id so the order is stable between rebuilds.
List<Product> rankDiscoverRound(
  Iterable<Product> products,
  DiscoverTaste taste, {
  Set<String> chosenFirst = const {},
}) {
  final scored = [
    for (final product in products)
      (
        product: product,
        chosen: chosenFirst.contains(product.categoryId) ? 1 : 0,
        score: taste.scoreOf(product) + (product.isFeatured ? 0.5 : 0),
      ),
  ];
  scored.sort((a, b) {
    final byChosen = b.chosen.compareTo(a.chosen);
    if (byChosen != 0) return byChosen;
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byDate = b.product.createdAt.compareTo(a.product.createdAt);
    if (byDate != 0) return byDate;
    return a.product.id.compareTo(b.product.id);
  });
  return [for (final entry in scored) entry.product];
}

/// Deterministic shuffle of [pool] for [round]: preferred categories first,
/// each group shuffled with a per-round seed, so every pass feels new but the
/// order is stable while the buyer is mid-round.
List<Product> recycleOrder(
  List<Product> pool,
  DiscoveryPreferences preferences,
  int round,
) {
  final sorted = [...pool]..sort((a, b) => a.id.compareTo(b.id));
  final random = Random(round * 7919 + sorted.length);
  final preferred =
      sorted
          .where((p) => preferences.categoryIds.contains(p.categoryId))
          .toList()
        ..shuffle(random);
  final rest =
      sorted
          .where((p) => !preferences.categoryIds.contains(p.categoryId))
          .toList()
        ..shuffle(random);
  return [...preferred, ...rest];
}

bool _inBudget(Product product, DiscoveryPreferences preferences) =>
    preferences.maxBudget == null || product.price <= preferences.maxBudget!;

/// "up to R1000" for a budget, or "any price".
String discoverBudgetLabel(double? maxBudget) =>
    maxBudget == null ? 'any price' : 'up to R${maxBudget.toStringAsFixed(0)}';

/// Names of the chosen categories in a stable, readable form, e.g.
/// "Baby & Kids", "Home, Jewellery" or "Home, Jewellery +2 more".
/// Ids without a known name are skipped.
String? discoverCategoriesLabel(
  Set<String> categoryIds,
  Map<String, String> categoryNames,
) {
  final names = [
    for (final id in categoryIds)
      if ((categoryNames[id] ?? '').trim().isNotEmpty)
        categoryNames[id]!.trim(),
  ]..sort();
  if (names.isEmpty) return null;
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} +${names.length - 2} more';
}

/// The always-visible line on Discover that says what the buyer's choices
/// are doing, e.g. "Showing Baby & Kids · up to R1000".
String discoverChoicesSummary(
  DiscoveryPreferences preferences,
  Map<String, String> categoryNames,
) {
  final categories =
      discoverCategoriesLabel(preferences.categoryIds, categoryNames) ??
      'everything';
  return 'Showing $categories · ${discoverBudgetLabel(preferences.maxBudget)}';
}

/// Live preview in the "Tune Discover" sheet of what saving will do.
String discoverChoicesPreview(
  Set<String> categoryIds,
  double? maxBudget,
  Map<String, String> categoryNames,
) {
  final categories = discoverCategoriesLabel(categoryIds, categoryNames);
  final budget = discoverBudgetLabel(maxBudget);
  if (categories == null) {
    return maxBudget == null
        ? 'Discover will show everything, ordered by what you love.'
        : 'Discover will show everything $budget first, ordered by what you love.';
  }
  return maxBudget == null
      ? 'Discover will show only $categories until you have seen them all, '
            'then other categories.'
      : 'Discover will show only $categories $budget until you have seen '
            'them all, then more in your budget from other categories.';
}

/// The line above the deck explaining the current round.
String discoverRoundIntro(
  DiscoverDeckMode mode, {
  required bool hasChosenCategories,
}) => switch (mode) {
  DiscoverDeckMode.otherCategories =>
    "More in your budget from other categories. You've seen every piece in your chosen ones.",
  DiscoverDeckMode.beyondBudget =>
    "You've seen everything within your budget, so here are more pieces just above it.",
  DiscoverDeckMode.recycled =>
    "You're all caught up on new pieces. Here's another look at ones you've seen, in a fresh order.",
  _ when hasChosenCategories =>
    'Only your chosen categories until you have seen them all. Love it, Save and Not for me fine-tune the order.',
  _ =>
    'Choose what fits. Every Love it, Save and Not for me tunes what you see next.',
};
