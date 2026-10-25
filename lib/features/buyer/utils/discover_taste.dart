import '../../../models/product.dart';
import 'discovery_preferences.dart';

/// What the buyer's own Discover choices say about their taste.
///
/// Built only from real signals the app already stores: pieces they
/// swiped "Love it" on and pieces they skipped ("Not for me"), both kept in
/// [DiscoveryPreferences], plus pieces they saved to favourites. Loved and
/// saved pieces boost their category, maker and tags; skipped pieces demote
/// them. Nothing extra is persisted: the profile is rebuilt from those
/// stored decisions each time, so it survives restarts and follows the
/// buyer across devices whenever their decisions do.
class DiscoverTaste {
  const DiscoverTaste._({
    required this.categories,
    required this.shops,
    required this.tags,
  });

  static const empty = DiscoverTaste._(
    categories: <String, double>{},
    shops: <String, double>{},
    tags: <String, double>{},
  );

  /// Net weight per category id (positive = more like this).
  final Map<String, double> categories;

  /// Net weight per maker (shop id).
  final Map<String, double> shops;

  /// Net weight per lower-cased tag.
  final Map<String, double> tags;

  bool get isEmpty => categories.isEmpty && shops.isEmpty && tags.isEmpty;

  // Signal weights. Loving a piece says more than saving it; skipping one is
  // a softer "less of this" so one skip never buries a whole category.
  static const _lovedCategory = 3.0;
  static const _lovedShop = 2.0;
  static const _lovedTag = 1.0;
  static const _savedCategory = 2.0;
  static const _savedShop = 1.5;
  static const _savedTag = 0.75;
  static const _skippedCategory = -1.5;
  static const _skippedShop = -1.0;
  static const _skippedTag = -0.5;

  /// Tags can add at most this much (or take away this much) per piece, so
  /// a heavily tagged piece can't outrank a category or maker match.
  static const _maxTagBoost = 3.0;
  static const _maxTagPenalty = -2.0;

  /// Builds a profile from loved, saved and skipped pieces. A piece that is
  /// both loved and saved counts once (as loved); a piece that is saved but
  /// was later skipped is treated as saved, because saving is the stronger,
  /// still-standing signal.
  factory DiscoverTaste.fromSignals({
    Iterable<Product> loved = const [],
    Iterable<Product> saved = const [],
    Iterable<Product> skipped = const [],
  }) {
    final categories = <String, double>{};
    final shops = <String, double>{};
    final tags = <String, double>{};
    final counted = <String>{};

    void add(Product product, double category, double shop, double tag) {
      if (!counted.add(product.id)) return;
      final categoryId = product.categoryId;
      if (categoryId != null && categoryId.isNotEmpty) {
        categories[categoryId] = (categories[categoryId] ?? 0) + category;
      }
      if (product.shopId.isNotEmpty) {
        shops[product.shopId] = (shops[product.shopId] ?? 0) + shop;
      }
      for (final value in _tagsOf(product)) {
        tags[value] = (tags[value] ?? 0) + tag;
      }
    }

    for (final product in loved) {
      add(product, _lovedCategory, _lovedShop, _lovedTag);
    }
    for (final product in saved) {
      add(product, _savedCategory, _savedShop, _savedTag);
    }
    for (final product in skipped) {
      add(product, _skippedCategory, _skippedShop, _skippedTag);
    }
    return DiscoverTaste._(categories: categories, shops: shops, tags: tags);
  }

  /// How strongly [product] matches this taste; 0 for no signal.
  double scoreOf(Product product) {
    var score = 0.0;
    final categoryId = product.categoryId;
    if (categoryId != null) score += categories[categoryId] ?? 0;
    score += shops[product.shopId] ?? 0;
    var tagScore = 0.0;
    for (final value in _tagsOf(product)) {
      tagScore += tags[value] ?? 0;
    }
    return score + tagScore.clamp(_maxTagPenalty, _maxTagBoost);
  }
}

Set<String> _tagsOf(Product product) => {
  for (final tag in product.tags)
    if (tag.trim().isNotEmpty) tag.trim().toLowerCase(),
};

/// The taste profile for [pool]: loved and skipped pieces come from the
/// buyer's stored Discover decisions, saved pieces from their favourites
/// ([savedProducts], plus any of [savedProductIds] found in [pool]).
DiscoverTaste discoverTasteFor(
  List<Product> pool,
  DiscoveryPreferences preferences, {
  Iterable<Product> savedProducts = const [],
  Set<String> savedProductIds = const {},
}) {
  if (preferences.likedProductIds.isEmpty &&
      preferences.skippedProductIds.isEmpty &&
      savedProductIds.isEmpty &&
      savedProducts.isEmpty) {
    return DiscoverTaste.empty;
  }
  return DiscoverTaste.fromSignals(
    loved: pool.where((p) => preferences.likedProductIds.contains(p.id)),
    saved: [
      ...savedProducts,
      ...pool.where((p) => savedProductIds.contains(p.id)),
    ],
    skipped: pool.where((p) => preferences.skippedProductIds.contains(p.id)),
  );
}
