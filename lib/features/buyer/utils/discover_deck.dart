import 'dart:math';

import '../../../models/product.dart';
import 'discovery_preferences.dart';

/// Where the cards currently on the Discover deck come from.
enum DiscoverDeckMode {
  /// Pieces the buyer hasn't decided on yet, within their budget, ranked by
  /// their preferences. The normal deck.
  fresh,

  /// Everything in budget has been reviewed (and there are no more pages to
  /// load), so the deck keeps going with undecided pieces above the budget.
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

  /// Size of the current pass (for the "n of total" counter).
  final int total;

  /// How many cards of the current pass are already behind the buyer.
  final int reviewed;

  bool get isEmpty => items.isEmpty;
}

/// Builds the Discover deck so it never dead-ends while real products exist.
///
/// 1. [DiscoverDeckMode.fresh]: undecided, in-budget pieces ranked by
///    [rankDiscoverProducts].
/// 2. When those run out and [canLoadMore] is true, returns an empty fresh
///    deck: the caller should fetch the next page of products.
/// 3. [DiscoverDeckMode.beyondBudget]: undecided pieces over the budget.
/// 4. [DiscoverDeckMode.recycled]: already-reviewed pieces (in budget when
///    there are any, otherwise all of them) in a shuffled order that changes
///    every round. [recycleCursor] counts the cards swiped while recycling;
///    it wraps into the next round automatically, so the deck is endless.
/// 5. [DiscoverDeckMode.empty] only when [products] is empty.
DiscoverDeck buildDiscoverDeck(
  List<Product> products,
  DiscoveryPreferences preferences, {
  bool canLoadMore = false,
  int recycleCursor = 0,
}) {
  final fresh = rankDiscoverProducts(products, preferences);
  if (fresh.isNotEmpty || canLoadMore) {
    final total = products.where((p) => _inBudget(p, preferences)).length;
    return DiscoverDeck(
      mode: DiscoverDeckMode.fresh,
      items: fresh,
      total: total,
      reviewed: (total - fresh.length).clamp(0, total),
    );
  }
  if (products.isEmpty) {
    return const DiscoverDeck(
      mode: DiscoverDeckMode.empty,
      items: [],
      total: 0,
      reviewed: 0,
    );
  }

  bool decided(Product p) =>
      preferences.likedProductIds.contains(p.id) ||
      preferences.skippedProductIds.contains(p.id);

  final beyond = rankDiscoverProducts(
    products,
    preferences.copyWith(clearBudget: true),
  ).where((p) => !_inBudget(p, preferences)).toList();
  if (beyond.isNotEmpty) {
    final total = products.where((p) => !_inBudget(p, preferences)).length;
    return DiscoverDeck(
      mode: DiscoverDeckMode.beyondBudget,
      items: beyond,
      total: total,
      reviewed: (total - beyond.length).clamp(0, total),
    );
  }

  final reviewed = products.where(decided).toList();
  final inBudget = reviewed.where((p) => _inBudget(p, preferences)).toList();
  final pool = inBudget.isNotEmpty ? inBudget : reviewed;
  final cursor = max(0, recycleCursor);
  final round = cursor ~/ pool.length;
  final offset = cursor % pool.length;
  final thisRound = recycleOrder(pool, preferences, round);
  // Append the next round so the peeking "next" card is never blank.
  final items = [
    ...thisRound.sublist(offset),
    ...recycleOrder(pool, preferences, round + 1),
  ];
  return DiscoverDeck(
    mode: DiscoverDeckMode.recycled,
    items: items,
    total: pool.length,
    reviewed: offset,
  );
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
