import 'dart:async';

import 'package:artisanal_lane/features/buyer/providers/gift_finder_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/gift_concierge_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_discovery_gift.dart';
import 'package:artisanal_lane/features/buyer/widgets/gift_result_card.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Product _product(
  String id, {
  required double price,
  String title = 'Item',
  List<String> tags = const [],
  int stockQty = 5,
  String? shopName = 'Clay & Co',
}) => Product(
  id: id,
  shopId: 'shop-$id',
  title: title,
  price: price,
  stockQty: stockQty,
  tags: tags,
  isPublished: true,
  shopName: shopName,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpFinder(
    WidgetTester tester,
    Future<List<Product>> Function() load, {
    Size size = const Size(360, 640),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [giftCatalogueProvider.overrideWith((ref) => load())],
        child: MaterialApp(
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: const GiftConciergeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> answer(
    WidgetTester tester, {
    String recipient = 'Her',
    String occasion = 'Birthday',
    String budget = 'Under R250',
    List<String> interests = const [],
  }) async {
    await tapVisible(tester, find.text(recipient));
    await tapVisible(tester, find.text(occasion));
    await tapVisible(tester, find.text(budget));
    for (final interest in interests) {
      await tapVisible(tester, find.text(interest));
    }
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('gift-finder-submit')));
    await tester.pump();
  }

  testWidgets('primary action stays disabled until the three required '
      'questions are answered', (tester) async {
    await pumpFinder(tester, () async => const []);
    expect(find.text("Find a gift they'll love"), findsOneWidget);
    expect(find.text('Answer 3 more questions'), findsOneWidget);

    await tapVisible(tester, find.text('Her'));
    expect(find.text('Answer 2 more questions'), findsOneWidget);
    await tapVisible(tester, find.text('Birthday'));
    expect(find.text('Answer 1 more question'), findsOneWidget);
    await tapVisible(tester, find.text('Under R250'));
    expect(find.text('Show gift ideas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a skeleton while the catalogue loads', (tester) async {
    final completer = Completer<List<Product>>();
    await pumpFinder(tester, () => completer.future);
    await answer(tester);
    await submit(tester);

    expect(find.byKey(const Key('gift-finder-loading')), findsOneWidget);
    expect(find.byType(GiftResultCard), findsNothing);

    completer.complete([_product('a', price: 100, title: 'Beaded necklace')]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('gift-finder-loading')), findsNothing);
    expect(find.byType(GiftResultCard), findsOneWidget);
  });

  testWidgets('results are real products, interests first, with a reason', (
    tester,
  ) async {
    await pumpFinder(
      tester,
      () async => [
        _product('mug', price: 120, title: 'Speckled mug'),
        _product('necklace', price: 180, title: 'Beaded necklace'),
        _product('pricey', price: 900, title: 'Large woven basket'),
        _product('sold-out', price: 90, title: 'Clay bowl', stockQty: 0),
      ],
    );
    await answer(tester, interests: const ['Kitchen & table']);
    await submit(tester);
    await tester.pump();

    expect(find.text('Gift ideas'), findsOneWidget);
    expect(find.text('2 ideas'), findsOneWidget);
    // Out of budget and sold-out pieces never appear.
    expect(find.text('Large woven basket'), findsNothing);
    expect(find.text('Clay bowl'), findsNothing);
    final cards = tester
        .widgetList<GiftResultCard>(find.byType(GiftResultCard))
        .toList();
    expect(cards.first.recommendation.product.id, 'mug');
    expect(find.text('Matches kitchen & table'), findsOneWidget);
    expect(find.text('Clay & Co'), findsNWidgets(2));
    expect(find.text('R120'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Edit returns to the questions with answers kept.
    await tapVisible(tester, find.text('Edit'));
    expect(find.text('Show gift ideas'), findsOneWidget);
  });

  testWidgets('empty state suggests widening the budget and can do it', (
    tester,
  ) async {
    await pumpFinder(
      tester,
      () async => [_product('pricey', price: 900, title: 'Woven basket')],
    );
    await answer(tester);
    await submit(tester);
    await tester.pump();

    expect(find.byKey(const Key('gift-finder-empty')), findsOneWidget);
    expect(find.text('No matches — try widening your budget.'), findsOneWidget);

    await tapVisible(tester, find.text('Widen my budget'));
    expect(find.byKey(const Key('gift-finder-empty')), findsNothing);
    expect(find.text('Woven basket'), findsOneWidget);
  });

  testWidgets('error state is friendly and retries', (tester) async {
    var calls = 0;
    await pumpFinder(tester, () async {
      calls++;
      if (calls == 1) throw Exception('boom: internal details');
      return [_product('a', price: 100, title: 'Beaded necklace')];
    });
    await answer(tester);
    await submit(tester);
    await tester.pump();

    expect(find.text("Couldn't load gift ideas"), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);

    await tapVisible(tester, find.text('Try again'));
    await tester.pump();
    expect(find.text('Beaded necklace'), findsOneWidget);
  });

  testWidgets('small phone with large text: questions and results have no '
      'overflow', (tester) async {
    await pumpFinder(
      tester,
      () async => [
        for (var i = 0; i < 5; i++)
          _product(
            'p$i',
            price: 150,
            title: 'A long handmade product title number $i for testing',
            shopName: 'A maker with a rather long shop name',
          ),
      ],
      size: const Size(360, 640),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await answer(tester, interests: const ['Jewellery', 'Toys & play']);
    expect(tester.takeException(), isNull);
    await submit(tester);
    await tester.pump();
    expect(find.byType(GiftResultCard), findsNWidgets(5));
    await tester.drag(
      find.byKey(const Key('gift-finder-scroll')),
      const Offset(0, -2000),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('large phone shows results without overflow', (tester) async {
    await pumpFinder(
      tester,
      () async => [
        for (var i = 0; i < 7; i++) _product('p$i', price: 150, title: 'Bowl $i'),
      ],
      size: const Size(430, 932),
    );
    await answer(tester);
    await submit(tester);
    await tester.pump();
    expect(find.byType(GiftResultCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('recommendGifts', () {
    test('ranks chosen interests first and keeps base order otherwise', () {
      final results = recommendGifts(
        products: [
          _product('a', price: 100, title: 'Plain item'),
          _product('b', price: 100, title: 'Leather wallet'),
          _product('c', price: 100, title: 'Other item'),
        ],
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.any,
        interests: {GiftInterest.leather},
      );
      expect(results.first.product.id, 'b');
      expect(results.first.reason, 'Matches leather goods');
      expect(results.map((r) => r.product.id).skip(1), ['a', 'c']);
    });

    test('drops products that cannot be bought and respects the limit', () {
      final results = recommendGifts(
        products: [
          for (var i = 0; i < 30; i++) _product('p$i', price: 100),
          _product('gone', price: 100, stockQty: 0),
        ],
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.any,
      );
      expect(results, hasLength(24));
      expect(results.any((r) => r.product.id == 'gone'), isFalse);
    });
  });
}
