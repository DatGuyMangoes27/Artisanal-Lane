import 'package:artisanal_lane/features/buyer/providers/discover_feed_provider.dart';
import 'package:artisanal_lane/features/buyer/utils/discover_deck.dart';
import 'package:artisanal_lane/features/buyer/utils/discovery_preferences.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 22);
  Product product(
    String id, {
    String categoryId = 'home',
    double price = 300,
  }) => Product(
    id: id,
    shopId: 'shop',
    categoryId: categoryId,
    title: id,
    price: price,
    stockQty: 1,
    createdAt: now,
    updatedAt: now,
  );

  final products = [
    product('a'),
    product('b'),
    product('ring', categoryId: 'jewellery'),
    product('pricey', price: 900),
  ];

  test('fresh deck shows undecided in-budget pieces', () {
    final deck = buildDiscoverDeck(
      products,
      const DiscoveryPreferences(maxBudget: 500, skippedProductIds: {'a'}),
    );
    expect(deck.mode, DiscoverDeckMode.fresh);
    expect(deck.items.map((p) => p.id).toSet(), {'b', 'ring'});
    expect(deck.total, 3);
    expect(deck.reviewed, 1);
  });

  test('an exhausted page asks for more before relaxing anything', () {
    final deck = buildDiscoverDeck(
      products,
      const DiscoveryPreferences(
        skippedProductIds: {'a', 'b', 'ring', 'pricey'},
      ),
      canLoadMore: true,
    );
    expect(deck.mode, DiscoverDeckMode.fresh);
    expect(deck.isEmpty, isTrue);
  });

  test('when the budget is exhausted it continues with pieces above it', () {
    final deck = buildDiscoverDeck(
      products,
      const DiscoveryPreferences(
        maxBudget: 500,
        likedProductIds: {'a'},
        skippedProductIds: {'b', 'ring'},
      ),
    );
    expect(deck.mode, DiscoverDeckMode.beyondBudget);
    expect(deck.items.map((p) => p.id), ['pricey']);
  });

  test('when everything is reviewed it recycles, preferred categories first, '
      'and wraps into new rounds forever', () {
    const prefs = DiscoveryPreferences(
      categoryIds: {'jewellery'},
      maxBudget: 500,
      likedProductIds: {'a', 'pricey'},
      skippedProductIds: {'b', 'ring'},
    );
    final first = buildDiscoverDeck(products, prefs);
    expect(first.mode, DiscoverDeckMode.recycled);
    // In-budget reviewed pieces only (pricey is over budget).
    expect(first.total, 3);
    expect(first.items.first.id, 'ring');
    expect(first.items.take(3).map((p) => p.id).toSet(), {'a', 'b', 'ring'});

    for (var cursor = 0; cursor < 20; cursor++) {
      final deck = buildDiscoverDeck(products, prefs, recycleCursor: cursor);
      expect(deck.isEmpty, isFalse, reason: 'cursor $cursor');
      expect(deck.reviewed, cursor % 3);
      if (cursor % 3 == 0) expect(deck.items.first.id, 'ring');
    }
  });

  test('the deck is only empty when there are no products at all', () {
    expect(
      buildDiscoverDeck(const [], const DiscoveryPreferences()).mode,
      DiscoverDeckMode.empty,
    );
  });

  test('the feed pages through products and stops at the last page', () async {
    final all = List.generate(discoverPageSize + 5, (i) => product('p$i'));
    final offsets = <int>[];
    final container = ProviderContainer(
      overrides: [
        discoverPageFetcherProvider.overrideWithValue(({
          required int offset,
          required int limit,
        }) async {
          offsets.add(offset);
          return all.skip(offset).take(limit).toList();
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(discoverFeedProvider, (_, __) {});
    addTearDown(sub.close);

    final firstPage = await container.read(discoverFeedProvider.future);
    expect(firstPage.products, hasLength(discoverPageSize));
    expect(firstPage.hasMore, isTrue);

    await container.read(discoverFeedProvider.notifier).loadMore();
    final feed = container.read(discoverFeedProvider).value!;
    expect(feed.products, hasLength(discoverPageSize + 5));
    expect(feed.hasMore, isFalse);
    expect(offsets, [0, discoverPageSize]);

    await container.read(discoverFeedProvider.notifier).loadMore();
    expect(offsets, [0, discoverPageSize]);
  });
}
