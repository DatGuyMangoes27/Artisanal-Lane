import 'package:artisanal_lane/features/buyer/providers/gift_finder_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/gift_concierge_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_discovery_gift.dart';
import 'package:artisanal_lane/features/buyer/widgets/gift_result_card.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/product_variant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _date = DateTime(2026, 1, 1);

Product _product(
  String id, {
  required double price,
  String title = 'Item',
  String? categoryName,
  String? subcategoryName,
  List<String> tags = const [],
  int stockQty = 5,
  String fulfillmentMode = 'stocked',
  double? madeToOrderPrice,
  List<ProductVariant> variants = const [],
  String shopName = 'Maker',
}) => Product(
  id: id,
  shopId: 'shop-$id',
  title: title,
  price: price,
  stockQty: stockQty,
  tags: tags,
  categoryName: categoryName,
  subcategoryName: subcategoryName,
  fulfillmentMode: fulfillmentMode,
  madeToOrderPrice: madeToOrderPrice,
  variants: variants,
  isPublished: true,
  shopName: shopName,
  createdAt: _date,
  updatedAt: _date,
);

/// Mirrors the catalogue from the client's report: For her, Birthday,
/// R500–R1000, Jewellery.
List<Product> _clientCatalogue() => [
  _product(
    'spark',
    price: 289,
    title: 'Willow Spark',
    categoryName: 'Jewellery',
    subcategoryName: 'Earrings',
    tags: const ['earring', 'pearl', 'jewellery'],
    shopName: 'Willow & Pearl',
  ),
  _product(
    'gold',
    price: 299,
    title: 'Willow Gold',
    categoryName: 'Jewellery',
    subcategoryName: 'Necklaces',
    tags: const ['necklace', 'pearl', 'jewellery'],
    shopName: 'Willow & Pearl',
  ),
  _product(
    'halo',
    price: 349,
    title: 'Willow Halo',
    categoryName: 'Jewellery',
    subcategoryName: 'Necklaces',
    tags: const ['necklace', 'pearl', 'jewellery'],
    shopName: 'Willow & Pearl',
  ),
  _product(
    'bag',
    price: 400,
    title: 'Handmade Beaded Bag',
    categoryName: 'Art & Design',
    subcategoryName: 'Other',
    shopName: 'Agna beads',
  ),
  _product(
    'pricey-bag',
    price: 700,
    title: 'Handmade Beaded Bag',
    categoryName: 'Art & Design',
    subcategoryName: 'Other',
    shopName: 'Agna beads',
  ),
  _product(
    'bangle',
    price: 800,
    title: 'Silver bangle',
    categoryName: 'Jewellery',
    shopName: 'Silversmith',
  ),
  _product(
    'pendant',
    price: 700,
    title: 'Brass pendant',
    tags: const ['jewellery'],
    shopName: 'Silversmith',
  ),
  _product(
    'vase',
    price: 650,
    title: 'Tall vase',
    categoryName: 'Home',
    shopName: 'Clay & Co',
  ),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('giftPrice', () {
    test('uses the default variant price when the product has variants', () {
      final product = _product(
        'v',
        price: 300,
        variants: [
          ProductVariant(
            id: 'v1',
            productId: 'v',
            displayName: 'Large',
            price: 650,
            stockQty: 2,
            createdAt: _date,
            updatedAt: _date,
          ),
        ],
      );
      expect(giftPrice(product), 650);
      expect(GiftBudget.between500And1000.matches(giftPrice(product)), isTrue);
    });

    test('uses the made-to-order price when the piece is sold to order', () {
      final product = _product(
        'm',
        price: 600,
        stockQty: 0,
        fulfillmentMode: 'made_to_order',
        madeToOrderPrice: 450,
      );
      expect(giftPrice(product), 450);
      final results = recommendGifts(
        products: [product],
        recipient: GiftRecipient.anyone,
        occasion: GiftOccasion.justBecause,
        budget: GiftBudget.between500And1000,
      );
      expect(results, isEmpty);
    });

    test('stocked piece with stock keeps its normal price', () {
      final product = _product(
        's',
        price: 600,
        fulfillmentMode: 'stocked_with_mto',
        madeToOrderPrice: 450,
      );
      expect(giftPrice(product), 600);
    });
  });

  group('matchedGiftInterests', () {
    test('a beaded bag is not jewellery', () {
      final bag = _product('bag', price: 400, title: 'Handmade Beaded Bag');
      expect(matchedGiftInterests(bag, {GiftInterest.jewellery}), isEmpty);
    });

    test('category, subcategory, tags and plural titles all count', () {
      for (final product in [
        _product('a', price: 1, categoryName: 'Jewellery'),
        _product('b', price: 1, subcategoryName: 'Earrings'),
        _product('c', price: 1, tags: const ['jewellery']),
        _product('d', price: 1, title: 'Handmade Bracelets'),
      ]) {
        expect(
          matchedGiftInterests(product, {GiftInterest.jewellery}),
          [GiftInterest.jewellery],
          reason: product.id,
        );
      }
    });

    test('whole words only: "artisan" and "heart" are not art', () {
      final mug = _product('m', price: 1, title: 'Artisan heart mug');
      expect(matchedGiftInterests(mug, {GiftInterest.art}), isEmpty);
    });
  });

  group('findGiftIdeas (client report)', () {
    GiftFinderResults run() => findGiftIdeas(
      products: _clientCatalogue(),
      recipient: GiftRecipient.her,
      occasion: GiftOccasion.birthday,
      budget: GiftBudget.between500And1000,
      interests: {GiftInterest.jewellery},
    );

    test('matches are only in-budget jewellery', () {
      final results = run();
      expect(results.matches.map((r) => r.product.id).toSet(), {
        'bangle',
        'pendant',
      });
      for (final match in results.matches) {
        expect(
          GiftBudget.between500And1000.matches(giftPrice(match.product)),
          isTrue,
        );
        expect(match.reason, 'Matches jewellery');
      }
    });

    test('close matches are separate, in-category, nearest first, and '
        'never labelled as matching', () {
      final results = run();
      expect(results.closeMatches.map((r) => r.product.id), [
        'halo',
        'gold',
        'spark',
      ]);
      for (final close in results.closeMatches) {
        expect(close.reason, 'Under your budget');
        expect(close.reason.startsWith('Matches'), isFalse);
      }
      final all = [...results.matches, ...results.closeMatches];
      expect(all.any((r) => r.product.id.contains('bag')), isFalse);
      expect(all.any((r) => r.product.id == 'vase'), isFalse);
    });

    test('no close matches once there are plenty of real ones', () {
      final results = findGiftIdeas(
        products: [
          for (var i = 0; i < giftCloseMatchThreshold; i++)
            _product('n$i', price: 600, title: 'Necklace $i'),
          _product('cheap', price: 100, title: 'Necklace cheap'),
        ],
        recipient: GiftRecipient.her,
        occasion: GiftOccasion.birthday,
        budget: GiftBudget.between500And1000,
        interests: {GiftInterest.jewellery},
      );
      expect(results.matches, hasLength(giftCloseMatchThreshold));
      expect(results.closeMatches, isEmpty);
    });

    test('over-budget pieces are labelled as over', () {
      final results = findGiftIdeas(
        products: [_product('big', price: 1500, title: 'Gold necklace')],
        recipient: GiftRecipient.her,
        occasion: GiftOccasion.birthday,
        budget: GiftBudget.between500And1000,
        interests: {GiftInterest.jewellery},
      );
      expect(results.matches, isEmpty);
      expect(results.closeMatches.single.reason, 'Over your budget');
    });
  });

  testWidgets('screen: header counts only true matches and close matches sit '
      'in their own labelled section', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          giftCatalogueProvider.overrideWith((ref) async => _clientCatalogue()),
        ],
        child: const MaterialApp(home: GiftConciergeScreen()),
      ),
    );
    await tester.pump();

    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(text));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tap('Her');
    await tap('Birthday');
    await tap('R500–R1000');
    await tap('Jewellery');
    await tester.tap(find.byKey(const Key('gift-finder-submit')));
    await tester.pump();
    await tester.pump();

    expect(find.text('2 ideas'), findsOneWidget);
    final matchCards = find.descendant(
      of: find.byKey(const Key('gift-finder-matches')),
      matching: find.byType(GiftResultCard),
    );
    expect(matchCards, findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(const Key('gift-finder-matches')),
        matching: find.text('Willow Spark'),
      ),
      findsNothing,
    );

    final close = find.byKey(const Key('gift-finder-close-matches'));
    expect(close, findsOneWidget);
    expect(
      find.descendant(
        of: close,
        matching: find.text('Close matches outside your budget'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: close, matching: find.text('Willow Spark')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: close, matching: find.text('Matches jewellery')),
      findsNothing,
    );
    expect(find.text('Handmade Beaded Bag'), findsNothing);
    expect(find.text('Matches jewellery'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen: zero matches shows the empty notice plus close '
      'matches, never a match count', (tester) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          giftCatalogueProvider.overrideWith(
            (ref) async => [
              _product(
                'spark',
                price: 289,
                title: 'Willow Spark',
                tags: const ['earring'],
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: GiftConciergeScreen()),
      ),
    );
    await tester.pump();
    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(text));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tap('Her');
    await tap('Birthday');
    await tap('R500–R1000');
    await tap('Jewellery');
    await tester.tap(find.byKey(const Key('gift-finder-submit')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('gift-finder-empty')), findsOneWidget);
    expect(find.byKey(const Key('gift-finder-match-count')), findsNothing);
    expect(find.byKey(const Key('gift-finder-close-matches')), findsOneWidget);
    expect(find.text('Under your budget'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
