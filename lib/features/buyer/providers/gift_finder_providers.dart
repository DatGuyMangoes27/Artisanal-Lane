import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../utils/shop_discovery_gift.dart';
import 'buyer_providers.dart';

/// Optional fourth step of the gift finder: what the person is into.
enum GiftInterest {
  jewellery,
  homeDecor,
  kitchen,
  textiles,
  beauty,
  art,
  leather,
  toys,
}

extension GiftInterestDetails on GiftInterest {
  String get label => switch (this) {
    GiftInterest.jewellery => 'Jewellery',
    GiftInterest.homeDecor => 'Home decor',
    GiftInterest.kitchen => 'Kitchen & table',
    GiftInterest.textiles => 'Textiles',
    GiftInterest.beauty => 'Beauty & scent',
    GiftInterest.art => 'Art & prints',
    GiftInterest.leather => 'Leather goods',
    GiftInterest.toys => 'Toys & play',
  };

  IconData get icon => switch (this) {
    GiftInterest.jewellery => Icons.diamond_outlined,
    GiftInterest.homeDecor => Icons.chair_outlined,
    GiftInterest.kitchen => Icons.coffee_outlined,
    GiftInterest.textiles => Icons.checkroom_outlined,
    GiftInterest.beauty => Icons.spa_outlined,
    GiftInterest.art => Icons.palette_outlined,
    GiftInterest.leather => Icons.wallet_outlined,
    GiftInterest.toys => Icons.toys_outlined,
  };

  /// Whole words (singular; plurals match too) that put a product in this
  /// interest. They are matched against whole words of the title, category,
  /// subcategory and tags, never substrings, so a "beaded bag" is not
  /// jewellery and an "artisan" mug is not art.
  List<String> get keywords => switch (this) {
    GiftInterest.jewellery => const [
      'jewellery',
      'jewelry',
      'jewel',
      'earring',
      'necklace',
      'bracelet',
      'pendant',
      'bangle',
      'ring',
      'anklet',
      'brooch',
      'choker',
    ],
    GiftInterest.homeDecor => const [
      'decor',
      'candle',
      'vase',
      'cushion',
      'basket',
      'wall',
      'home',
      'plant',
      'planter',
    ],
    GiftInterest.kitchen => const [
      'kitchen',
      'kitchenware',
      'bowl',
      'mug',
      'plate',
      'cup',
      'board',
      'table',
      'tableware',
      'serving',
      'ceramic',
    ],
    GiftInterest.textiles => const [
      'textile',
      'woven',
      'weave',
      'scarf',
      'throw',
      'blanket',
      'cotton',
      'linen',
      'shweshwe',
    ],
    GiftInterest.beauty => const [
      'soap',
      'skincare',
      'beauty',
      'perfume',
      'fragrance',
      'balm',
      'scent',
    ],
    GiftInterest.art => const [
      'art',
      'print',
      'painting',
      'sculpture',
      'frame',
      'carving',
      'canvas',
    ],
    GiftInterest.leather => const ['leather', 'wallet', 'belt'],
    GiftInterest.toys => const [
      'toy',
      'kid',
      'plush',
      'puzzle',
      'game',
      'doll',
      'baby',
    ],
  };
}

/// One gift idea: a real, buyable product plus a short line saying why it
/// made the shortlist.
class GiftRecommendation {
  const GiftRecommendation({required this.product, required this.reason});
  final Product product;
  final String reason;
}

/// The published catalogue the gift finder ranks. Read-only; reuses the
/// existing "shop all" catalogue query so results are always real products.
final giftCatalogueProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(
    categoryProductsProvider(
      const CategoryProductFilter(categoryId: ''),
    ).future,
  ),
);

final _wordSplitter = RegExp(r'[^a-zÀ-ɏ]+');

Set<String> _words(Product product) => <String>[
  product.title,
  product.categoryName ?? '',
  product.subcategoryName ?? '',
  ...product.tags,
].join(' ').toLowerCase().split(_wordSplitter).toSet();

bool _hasWord(Set<String> words, String keyword) =>
    words.contains(keyword) ||
    words.contains('${keyword}s') ||
    words.contains('${keyword}es');

/// Interests from [interests] that [product] genuinely matches: one of the
/// interest's keywords appears as a whole word in its title, category,
/// subcategory or tags.
List<GiftInterest> matchedGiftInterests(
  Product product,
  Set<GiftInterest> interests,
) {
  if (interests.isEmpty) return const [];
  final words = _words(product);
  return [
    for (final interest in GiftInterest.values)
      if (interests.contains(interest) &&
          interest.keywords.any((keyword) => _hasWord(words, keyword)))
        interest,
  ];
}

/// With fewer true matches than this, the finder also offers close matches.
const int giftCloseMatchThreshold = 6;

/// The finder's answer, split so out-of-budget pieces can never be mixed in
/// with, or counted as, real matches.
class GiftFinderResults {
  const GiftFinderResults({
    required this.matches,
    this.closeMatches = const [],
  });

  /// Pieces inside the budget that match every chosen answer.
  final List<GiftRecommendation> matches;

  /// Shown in their own section, only when [matches] is short: pieces that
  /// fit the chosen interests (if any) but sit outside the budget, nearest
  /// price first.
  final List<GiftRecommendation> closeMatches;

  bool get isEmpty => matches.isEmpty && closeMatches.isEmpty;
}

/// Builds the strict shortlist. Every result is published, buyable, priced
/// (by [giftPrice], the price the buyer sees) inside [budget] and, when
/// [interests] are chosen, genuinely matches at least one of them.
/// Recipient/occasion affinity, stock and maker verification only order that
/// set; they never add to it. Pieces matching more chosen interests come
/// first.
List<GiftRecommendation> recommendGifts({
  required List<Product> products,
  required GiftRecipient recipient,
  required GiftOccasion occasion,
  required GiftBudget budget,
  Set<GiftInterest> interests = const {},
  int limit = 24,
}) {
  final ranked = rankGiftConciergeProducts(
    products: products.where((p) => p.isAvailableForPurchase).toList(),
    recipient: recipient,
    occasion: occasion,
    budget: budget,
  );
  final scored = [
    for (var i = 0; i < ranked.length; i++)
      (
        index: i,
        product: ranked[i],
        interests: matchedGiftInterests(ranked[i], interests),
        affinity: giftAffinityScore(
          product: ranked[i],
          recipient: recipient,
          occasion: occasion,
        ),
      ),
  ]..removeWhere((entry) => interests.isNotEmpty && entry.interests.isEmpty);
  scored.sort((a, b) {
    final byInterest = b.interests.length.compareTo(a.interests.length);
    return byInterest != 0 ? byInterest : a.index.compareTo(b.index);
  });

  String reasonFor(
    ({int index, Product product, List<GiftInterest> interests, int affinity})
    entry,
  ) {
    if (entry.interests.isNotEmpty) {
      return 'Matches ${entry.interests.first.label.toLowerCase()}';
    }
    if (entry.affinity > 0 && recipient != GiftRecipient.anyone) {
      return recipient == GiftRecipient.home
          ? 'A good fit for the home'
          : 'A good fit for ${recipient.label.toLowerCase()}';
    }
    if (entry.product.shopIsVerified) return 'From a verified maker';
    if (entry.product.isMadeToOrderAvailable) return 'Made to order for you';
    return 'Within your budget';
  }

  return [
    for (final entry in scored.take(limit))
      GiftRecommendation(product: entry.product, reason: reasonFor(entry)),
  ];
}

/// Strict matches from [recommendGifts] plus, only when there are fewer
/// than [giftCloseMatchThreshold] of them, up to [closeLimit] close matches:
/// buyable pieces that fit the chosen interests but miss the budget, nearest
/// price first. Close matches say how they miss the budget and are never
/// labelled as matching.
GiftFinderResults findGiftIdeas({
  required List<Product> products,
  required GiftRecipient recipient,
  required GiftOccasion occasion,
  required GiftBudget budget,
  Set<GiftInterest> interests = const {},
  int limit = 24,
  int closeLimit = 6,
}) {
  final matches = recommendGifts(
    products: products,
    recipient: recipient,
    occasion: occasion,
    budget: budget,
    interests: interests,
    limit: limit,
  );
  if (matches.length >= giftCloseMatchThreshold || budget == GiftBudget.any) {
    return GiftFinderResults(matches: matches);
  }

  final outside = rankGiftConciergeProducts(
    products: [
      for (final product in products)
        if (product.isAvailableForPurchase &&
            !budget.matches(giftPrice(product)) &&
            (interests.isEmpty ||
                matchedGiftInterests(product, interests).isNotEmpty))
          product,
    ],
    recipient: recipient,
    occasion: occasion,
    budget: GiftBudget.any,
  );
  final ordered = [
    for (var i = 0; i < outside.length; i++)
      (
        index: i,
        product: outside[i],
        gap: budget.distanceFrom(giftPrice(outside[i])),
      ),
  ];
  ordered.sort((a, b) {
    final byGap = a.gap.compareTo(b.gap);
    return byGap != 0 ? byGap : a.index.compareTo(b.index);
  });

  return GiftFinderResults(
    matches: matches,
    closeMatches: [
      for (final entry in ordered.take(closeLimit))
        GiftRecommendation(
          product: entry.product,
          reason: budget.isBelow(giftPrice(entry.product))
              ? 'Under your budget'
              : 'Over your budget',
        ),
    ],
  );
}
