import 'package:artisanal_lane/features/buyer/providers/feed_ranking.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 28, 12);

  ShopPost post({
    required String id,
    required String shopId,
    List<String> productIds = const [],
    Duration age = Duration.zero,
  }) => ShopPost(
    id: id,
    shopId: shopId,
    caption: '',
    productIds: productIds,
    createdAt: now.subtract(age),
    updatedAt: now.subtract(age),
  );

  group('rankForYouFeed', () {
    test('is a pure function: same inputs always produce the same order', () {
      final posts = [
        post(id: 'a', shopId: 'shop-1', age: const Duration(hours: 1)),
        post(id: 'b', shopId: 'shop-2', age: const Duration(hours: 2)),
        post(id: 'c', shopId: 'shop-3', age: const Duration(hours: 3)),
      ];
      const signals = FeedRankingSignals();
      final first = rankForYouFeed(posts, signals.copyWithNow(now));
      final second = rankForYouFeed(posts, signals.copyWithNow(now));
      expect(first.map((p) => p.id), second.map((p) => p.id));
    });

    test('guests (empty signals) fall back to recency order', () {
      final posts = [
        post(id: 'oldest', shopId: 'shop-1', age: const Duration(hours: 5)),
        post(id: 'newest', shopId: 'shop-2', age: const Duration(hours: 1)),
        post(id: 'middle', shopId: 'shop-3', age: const Duration(hours: 3)),
      ];
      final ranked = rankForYouFeed(posts, FeedRankingSignals(now: now));
      expect(ranked.map((p) => p.id), ['newest', 'middle', 'oldest']);
    });

    test('boosts posts from followed makers above newer unfollowed posts', () {
      final posts = [
        post(
          id: 'newer-stranger',
          shopId: 'shop-2',
          age: const Duration(minutes: 5),
        ),
        post(
          id: 'older-followed',
          shopId: 'shop-1',
          age: const Duration(hours: 10),
        ),
      ];
      final ranked = rankForYouFeed(
        posts,
        FeedRankingSignals(followedShopIds: const {'shop-1'}, now: now),
      );
      expect(ranked.first.id, 'older-followed');
    });

    test('boosts posts tagging a liked product', () {
      final posts = [
        post(id: 'plain', shopId: 'shop-2', age: const Duration(hours: 1)),
        post(
          id: 'tagged',
          shopId: 'shop-3',
          productIds: const ['product-9'],
          age: const Duration(hours: 6),
        ),
      ];
      final ranked = rankForYouFeed(
        posts,
        FeedRankingSignals(likedProductIds: const {'product-9'}, now: now),
      );
      expect(ranked.first.id, 'tagged');
    });

    test('boosts posts tagging a liked or boosted category', () {
      final posts = [
        post(id: 'plain', shopId: 'shop-2', age: const Duration(hours: 1)),
        post(
          id: 'category-match',
          shopId: 'shop-3',
          productIds: const ['product-9'],
          age: const Duration(hours: 6),
        ),
      ];
      final ranked = rankForYouFeed(
        posts,
        FeedRankingSignals(
          likedCategoryIds: const {'jewellery'},
          categoryIdsByProductId: const {'product-9': 'jewellery'},
          now: now,
        ),
      );
      expect(ranked.first.id, 'category-match');
    });

    test('muted makers sink to the bottom', () {
      final posts = [
        post(id: 'muted', shopId: 'shop-1', age: Duration.zero),
        post(id: 'other', shopId: 'shop-2', age: const Duration(hours: 20)),
      ];
      final ranked = rankForYouFeed(
        posts,
        FeedRankingSignals(mutedShopIds: const {'shop-1'}, now: now),
      );
      expect(ranked.last.id, 'muted');
    });

    test('diversity keeps the same maker from appearing back-to-back when '
        'an alternative exists', () {
      final posts = [
        post(id: 'shop1-a', shopId: 'shop-1', age: const Duration(minutes: 1)),
        post(id: 'shop1-b', shopId: 'shop-1', age: const Duration(minutes: 2)),
        post(id: 'shop2-a', shopId: 'shop-2', age: const Duration(minutes: 3)),
      ];
      final ranked = rankForYouFeed(posts, FeedRankingSignals(now: now));
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i].shopId == ranked[i - 1].shopId, isFalse);
      }
      // No posts were dropped or duplicated by the diversity pass.
      expect(ranked.map((p) => p.id).toSet(), posts.map((p) => p.id).toSet());
    });

    test('diversity does not crash when every post is from the same maker', () {
      final posts = [
        post(id: 'a', shopId: 'shop-1', age: const Duration(minutes: 1)),
        post(id: 'b', shopId: 'shop-1', age: const Duration(minutes: 2)),
      ];
      final ranked = rankForYouFeed(posts, FeedRankingSignals(now: now));
      expect(ranked.length, 2);
    });

    test('empty input returns empty output', () {
      expect(rankForYouFeed(const [], FeedRankingSignals(now: now)), isEmpty);
    });
  });
}

extension on FeedRankingSignals {
  FeedRankingSignals copyWithNow(DateTime now) => FeedRankingSignals(
    followedShopIds: followedShopIds,
    favouritedShopIds: favouritedShopIds,
    likedCategoryIds: likedCategoryIds,
    likedProductIds: likedProductIds,
    categoryIdsByProductId: categoryIdsByProductId,
    mutedShopIds: mutedShopIds,
    boostedCategoryIds: boostedCategoryIds,
    now: now,
  );
}
