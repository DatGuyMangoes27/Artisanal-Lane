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

  List<String> get keywords => switch (this) {
    GiftInterest.jewellery => const [
      'jewel',
      'earring',
      'necklace',
      'bracelet',
      'bead',
      'pendant',
      'bangle',
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
    ],
    GiftInterest.kitchen => const [
      'kitchen',
      'bowl',
      'mug',
      'plate',
      'cup',
      'board',
      'table',
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
    GiftInterest.leather => const ['leather', 'wallet', 'belt', 'bag'],
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
    categoryProductsProvider(const CategoryProductFilter(categoryId: '')).future,
  ),
);

String _haystack(Product product) => <String>[
  product.title,
  product.categoryName ?? '',
  product.subcategoryName ?? '',
  ...product.tags,
].join(' ').toLowerCase();

/// Interests from [interests] that [product] plainly matches.
List<GiftInterest> matchedGiftInterests(
  Product product,
  Set<GiftInterest> interests,
) {
  if (interests.isEmpty) return const [];
  final text = _haystack(product);
  return [
    for (final interest in GiftInterest.values)
      if (interests.contains(interest) && interest.keywords.any(text.contains))
        interest,
  ];
}

/// Builds the shortlist: budget and recipient/occasion ranking come from
/// [rankGiftConciergeProducts]; chosen interests then lift matching pieces
/// to the top (stable, so the base order breaks ties). Only products a buyer
/// can actually purchase are returned.
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
  ];
  scored.sort((a, b) {
    final byInterest = b.interests.length.compareTo(a.interests.length);
    return byInterest != 0 ? byInterest : a.index.compareTo(b.index);
  });

  String reasonFor(
    ({
      int index,
      Product product,
      List<GiftInterest> interests,
      int affinity,
    })
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
