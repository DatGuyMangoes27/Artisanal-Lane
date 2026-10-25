import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/utils/discover_deck.dart';
import 'package:artisanal_lane/features/buyer/utils/discover_taste.dart';
import 'package:artisanal_lane/features/buyer/utils/discovery_preferences.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 10, 1);
  Product product(
    String id, {
    String categoryId = 'home',
    String shopId = 'maker',
    double price = 300,
    List<String> tags = const [],
    int ageDays = 0,
  }) => Product(
    id: id,
    shopId: shopId,
    categoryId: categoryId,
    title: id,
    price: price,
    stockQty: 1,
    tags: tags,
    createdAt: now.subtract(Duration(days: ageDays)),
    updatedAt: now,
  );

  List<String> ids(Iterable<Product> products) => [
    for (final p in products) p.id,
  ];

  group('preference-dominant deck', () {
    final products = [
      // Newest pieces are in other categories, so ordering by date alone
      // would put them first.
      product('vase', categoryId: 'home'),
      product('bowl', categoryId: 'home', ageDays: 1),
      product('rattle', categoryId: 'kids', ageDays: 3),
      product('blanket', categoryId: 'kids', ageDays: 4),
      product('pram', categoryId: 'kids', price: 1500, ageDays: 2),
      product('lamp', categoryId: 'home', price: 1200, ageDays: 5),
    ];
    const kidsUnder1000 = DiscoveryPreferences(
      categoryIds: {'kids'},
      maxBudget: 1000,
    );

    test('the first round shows ONLY the chosen categories within budget', () {
      final deck = buildDiscoverDeck(products, kidsUnder1000);
      expect(deck.mode, DiscoverDeckMode.fresh);
      expect(ids(deck.items), ['rattle', 'blanket']);
      expect(deck.total, 2);
      expect(deck.position, 1);
    });

    test('other categories wait until the chosen ones are exhausted, even '
        'if more pages could still hold chosen pieces', () {
      final deck = buildDiscoverDeck(
        products,
        kidsUnder1000.copyWith(skippedProductIds: {'rattle', 'blanket'}),
        canLoadMore: true,
      );
      expect(deck.mode, DiscoverDeckMode.fresh);
      expect(deck.isEmpty, isTrue, reason: 'caller loads the next page');
    });

    test('then "more in your budget from other categories", counted on '
        'their own', () {
      final deck = buildDiscoverDeck(
        products,
        kidsUnder1000.copyWith(likedProductIds: {'rattle', 'blanket'}),
      );
      expect(deck.mode, DiscoverDeckMode.otherCategories);
      expect(ids(deck.items), ['vase', 'bowl']);
      expect(deck.total, 2);
      expect(deck.position, 1);
      expect(
        discoverRoundIntro(deck.mode, hasChosenCategories: true),
        startsWith('More in your budget from other categories'),
      );
    });

    test('then over-budget pieces, chosen categories first', () {
      final deck = buildDiscoverDeck(
        products,
        kidsUnder1000.copyWith(
          likedProductIds: {'rattle', 'blanket'},
          skippedProductIds: {'vase', 'bowl'},
        ),
      );
      expect(deck.mode, DiscoverDeckMode.beyondBudget);
      expect(ids(deck.items), ['pram', 'lamp']);
    });

    test('with no categories chosen the whole budget is one round', () {
      final deck = buildDiscoverDeck(
        products,
        const DiscoveryPreferences(maxBudget: 1000),
      );
      expect(deck.mode, DiscoverDeckMode.fresh);
      expect(ids(deck.items).toSet(), {'vase', 'bowl', 'rattle', 'blanket'});
    });

    test('the summary line and sheet preview say what the choices do', () {
      const names = {'kids': 'Baby & Kids', 'home': 'Home'};
      expect(
        discoverChoicesSummary(kidsUnder1000, names),
        'Showing Baby & Kids · up to R1000',
      );
      expect(
        discoverChoicesSummary(const DiscoveryPreferences(), names),
        'Showing everything · any price',
      );
      expect(
        discoverChoicesPreview({'kids'}, 1000, names),
        contains('only Baby & Kids up to R1000'),
      );
      expect(
        discoverChoicesPreview({'kids'}, 1000, names),
        contains('more in your budget from other categories'),
      );
      expect(
        discoverCategoriesLabel(
          {'a', 'b', 'c', 'd'},
          {'a': 'Art', 'b': 'Bags', 'c': 'Candles', 'd': 'Decor'},
        ),
        'Art, Bags +2 more',
      );
    });
  });

  group('swipe learning', () {
    final loved = product(
      'loved',
      categoryId: 'jewellery',
      shopId: 'silversmith',
      tags: ['Silver'],
      ageDays: 9,
    );
    final skipped = product(
      'skipped',
      categoryId: 'candles',
      shopId: 'chandler',
      ageDays: 9,
    );
    final pool = [
      loved,
      skipped,
      product('new-candle', categoryId: 'candles', shopId: 'chandler'),
      product(
        'same-maker',
        categoryId: 'home',
        shopId: 'silversmith',
        ageDays: 2,
      ),
      product('same-tag', categoryId: 'home', tags: ['silver'], ageDays: 3),
      product('neutral', categoryId: 'home', ageDays: 1),
      product('ring', categoryId: 'jewellery', ageDays: 4),
    ];

    test('loved category/maker/tags rise; skipped ones sink', () {
      final deck = buildDiscoverDeck(
        pool,
        const DiscoveryPreferences(
          likedProductIds: {'loved'},
          skippedProductIds: {'skipped'},
        ),
      );
      expect(ids(deck.items), [
        'ring', // loved category
        'same-maker', // loved maker
        'same-tag', // loved tag (case-insensitive)
        'neutral',
        'new-candle', // skipped category and maker
      ]);
    });

    test('saved pieces boost too, and stronger than nothing', () {
      final taste = discoverTasteFor(
        pool,
        const DiscoveryPreferences(),
        savedProductIds: {'loved'},
      );
      expect(taste.scoreOf(pool[6]), greaterThan(0)); // ring
      expect(taste.scoreOf(pool[5]), 0); // neutral
      final lovedTaste = DiscoverTaste.fromSignals(loved: [loved]);
      final savedTaste = DiscoverTaste.fromSignals(saved: [loved]);
      expect(
        lovedTaste.scoreOf(pool[6]),
        greaterThan(savedTaste.scoreOf(pool[6])),
      );
    });

    test('learning re-orders within a round but never breaks the chosen '
        'categories rule', () {
      final deck = buildDiscoverDeck(
        pool,
        const DiscoveryPreferences(
          categoryIds: {'candles'},
          likedProductIds: {'loved'},
        ),
      );
      // The loved jewellery and its maker don't leak into the candles round.
      expect(ids(deck.items), ['new-candle', 'skipped']);
    });

    test('decisions persist in the existing swipe storage, so learning '
        'survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      ProviderContainer open() => ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
      );
      final first = open();
      await first.read(discoveryPreferencesProvider.future);
      final notifier = first.read(discoveryPreferencesProvider.notifier);
      await notifier.recordDecision('loved', liked: true);
      await notifier.recordDecision('skipped', liked: false);
      first.dispose();

      final second = open();
      addTearDown(second.dispose);
      final restored = await second.read(discoveryPreferencesProvider.future);
      final taste = discoverTasteFor(pool, restored);
      expect(taste.categories['jewellery'], greaterThan(0));
      expect(taste.categories['candles'], lessThan(0));
    });
  });

  group('round counter', () {
    final products = [
      product('a', ageDays: 0),
      product('b', ageDays: 1),
      product('c', ageDays: 2),
    ];

    test('counts within the current round and goes back down on undo', () {
      const start = DiscoveryPreferences();
      expect(buildDiscoverDeck(products, start).position, 1);
      final afterSwipe = start.copyWith(likedProductIds: {'a'});
      expect(buildDiscoverDeck(products, afterSwipe).position, 2);
      // Undo of a fresh swipe removes the decision again.
      expect(buildDiscoverDeck(products, start).position, 1);
    });

    test('recycled rounds step back with the cursor', () {
      const allSeen = DiscoveryPreferences(likedProductIds: {'a', 'b', 'c'});
      final second = buildDiscoverDeck(products, allSeen, recycleCursor: 1);
      final first = buildDiscoverDeck(products, allSeen, recycleCursor: 0);
      expect(second.mode, DiscoverDeckMode.recycled);
      expect(second.position, 2);
      expect(first.position, 1);
      expect(second.total, 3);
    });
  });
}
