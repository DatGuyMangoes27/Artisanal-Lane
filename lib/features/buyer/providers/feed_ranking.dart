import 'dart:math' as math;

import '../../../models/shop_post.dart';

/// Signals used to personalise the "For you" feed. Every field is optional
/// data the app already has lying around — nothing here triggers a new
/// fetch. Guests naturally produce an empty [FeedRankingSignals], which
/// makes [rankForYouFeed] fall back to recency plus diversity.
class FeedRankingSignals {
  const FeedRankingSignals({
    this.followedShopIds = const <String>{},
    this.favouritedShopIds = const <String>{},
    this.likedCategoryIds = const <String>{},
    this.likedProductIds = const <String>{},
    this.categoryIdsByProductId = const <String, String>{},
    this.mutedShopIds = const <String>{},
    this.boostedCategoryIds = const <String>{},
    this.now,
  });

  /// Makers the buyer already follows.
  final Set<String> followedShopIds;

  /// Shops behind a product the buyer favourited.
  final Set<String> favouritedShopIds;

  /// Categories the buyer picked or leaned toward in Discover.
  final Set<String> likedCategoryIds;

  /// Products the buyer liked while swiping in Discover.
  final Set<String> likedProductIds;

  /// Best-effort lookup from a tagged product id to its category, built
  /// from whatever product lists are already loaded elsewhere.
  final Map<String, String> categoryIdsByProductId;

  /// Makers the buyer asked to see fewer posts from ("Shape your feed").
  final Set<String> mutedShopIds;

  /// Categories the buyer asked to see more of ("Shape your feed").
  final Set<String> boostedCategoryIds;

  /// Clock override for deterministic tests.
  final DateTime? now;
}

const _followedShopBoost = 8.0;
const _favouritedShopBoost = 4.0;
const _likedProductBoost = 5.0;
const _likedCategoryBoost = 3.0;
const _boostedCategoryBoost = 3.0;
const _mutedShopPenalty = 12.0;
const _recencyWeight = 6.0;
// Half-ish life of the recency boost, in hours.
const _recencyHalfLifeHours = 36.0;

double _score(ShopPost post, FeedRankingSignals signals, DateTime now) {
  var score = 0.0;
  if (signals.followedShopIds.contains(post.shopId)) {
    score += _followedShopBoost;
  }
  if (signals.favouritedShopIds.contains(post.shopId)) {
    score += _favouritedShopBoost;
  }
  if (signals.mutedShopIds.contains(post.shopId)) score -= _mutedShopPenalty;
  for (final productId in post.productIds) {
    if (signals.likedProductIds.contains(productId)) {
      score += _likedProductBoost;
    }
    final categoryId = signals.categoryIdsByProductId[productId];
    if (categoryId != null) {
      if (signals.likedCategoryIds.contains(categoryId)) {
        score += _likedCategoryBoost;
      }
      if (signals.boostedCategoryIds.contains(categoryId)) {
        score += _boostedCategoryBoost;
      }
    }
  }
  final ageHours = now.difference(post.publishedAt).inSeconds / 3600.0;
  final recency = _recencyWeight * math.exp(-ageHours / _recencyHalfLifeHours);
  score += recency;
  return score;
}

/// Ranks already-fetched posts for the "For you" tab, on-device. Pure and
/// deterministic: the same posts and signals always produce the same order.
///
/// Order of operations: score every post from the signals above (recency
/// always contributes, so an empty [signals] still yields a sane newest-first
/// order), stable-sort by score (ties broken by recency), then apply a light
/// diversity pass so the same maker rarely appears back-to-back.
List<ShopPost> rankForYouFeed(
  List<ShopPost> posts,
  FeedRankingSignals signals,
) {
  if (posts.isEmpty) return const [];
  final now = signals.now ?? DateTime.now();
  final scored = posts
      .map((post) => MapEntry(post, _score(post, signals, now)))
      .toList();
  scored.sort((a, b) {
    final byScore = b.value.compareTo(a.value);
    if (byScore != 0) return byScore;
    return b.key.createdAt.compareTo(a.key.createdAt);
  });
  return _applyDiversity(scored.map((entry) => entry.key).toList());
}

/// Ranks the "For you" feed one loaded page at a time and concatenates the
/// pages in load order, so loading page N+1 can never move a post from an
/// earlier page. Re-ranking the whole list instead lets higher-scoring posts
/// from a freshly loaded page jump above the ones the buyer has already
/// scrolled past, pushing those back below the viewport where they show up
/// a second time. [pageOf] maps a post id to the page it arrived in; posts
/// without an entry are treated as page 0. Duplicate ids are dropped
/// (first occurrence wins).
List<ShopPost> rankForYouFeedByPage(
  List<ShopPost> posts,
  Map<String, int> pageOf,
  FeedRankingSignals signals,
) {
  if (posts.isEmpty) return const [];
  final pages = <int, List<ShopPost>>{};
  final seen = <String>{};
  for (final post in posts) {
    if (!seen.add(post.id)) continue;
    pages.putIfAbsent(pageOf[post.id] ?? 0, () => <ShopPost>[]).add(post);
  }
  final order = pages.keys.toList()..sort();
  return [for (final page in order) ...rankForYouFeed(pages[page]!, signals)];
}

/// Greedily reorders so a post never sits directly after another post from
/// the same shop, unless there is truly nothing else left to place. Only
/// swaps forward through the remaining queue, so it never fabricates a
/// reorder for a feed that's already diverse.
List<ShopPost> _applyDiversity(List<ShopPost> ranked) {
  final remaining = List<ShopPost>.from(ranked);
  final result = <ShopPost>[];
  while (remaining.isNotEmpty) {
    final lastShopId = result.isEmpty ? null : result.last.shopId;
    var pickIndex = 0;
    if (lastShopId != null && remaining[0].shopId == lastShopId) {
      final betterIndex = remaining.indexWhere(
        (post) => post.shopId != lastShopId,
      );
      if (betterIndex != -1) pickIndex = betterIndex;
    }
    result.add(remaining.removeAt(pickIndex));
  }
  return result;
}

/// Drops posts from makers the account has muted (server-side mute, hides
/// them entirely, unlike the lighter local "show fewer" downranking).
List<ShopPost> filterMutedPosts(
  List<ShopPost> posts,
  Set<String> mutedShopIds,
) => mutedShopIds.isEmpty
    ? posts
    : posts.where((post) => !mutedShopIds.contains(post.shopId)).toList();
