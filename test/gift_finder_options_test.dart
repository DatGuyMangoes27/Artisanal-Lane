import 'package:artisanal_lane/features/buyer/providers/gift_finder_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/gift_concierge_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/shop_discovery_gift.dart';
import 'package:artisanal_lane/features/buyer/widgets/gift_result_card.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _date = DateTime(2026, 1, 1);

Product _product(
  String id, {
  required double price,
  required String title,
  String? categoryName,
  String? subcategoryName,
  List<String> tags = const [],
}) => Product(
  id: id,
  shopId: 'shop-$id',
  title: title,
  price: price,
  stockQty: 3,
  tags: tags,
  categoryName: categoryName,
  subcategoryName: subcategoryName,
  isPublished: true,
  shopName: 'Maker',
  createdAt: _date,
  updatedAt: _date,
);

final _catalogue = [
  _product(
    'clip',
    price: 120,
    title: 'Beaded hair clip',
    categoryName: 'Accessories',
    subcategoryName: 'Hair',
  ),
  _product('belt', price: 220, title: 'Leather belt'),
  _product(
    'xmas-bag',
    price: 180,
    title: 'Woven tote bag',
    tags: const ['christmas', 'festive'],
  ),
  _product(
    'kids-acc',
    price: 90,
    title: 'Sun hat',
    categoryName: 'Baby & Kids',
    subcategoryName: 'Accessories',
  ),
  _product('oil', price: 150, title: 'Hair oil', categoryName: 'Beauty'),
  _product('ring', price: 200, title: 'Silver ring', categoryName: 'Jewellery'),
  _product(
    'pricey-bag',
    price: 900,
    title: 'Leather handbag',
    categoryName: 'Accessories',
  ),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('seasonal and life-event occasions are offered', () {
    final labels = GiftOccasion.values.map((o) => o.label).toList();
    expect(
      labels,
      containsAll([
        'Christmas',
        'Easter',
        "Mother's Day",
        "Father's Day",
        "Valentine's",
        'Anniversary',
        'Housewarming',
        'New baby',
      ]),
    );
    // The original options are kept.
    expect(
      labels,
      containsAll(['Birthday', 'Thank you', 'Wedding', 'Just because']),
    );
  });

  test('Accessories matches the accessories category and accessory words, '
      'never look-alikes', () {
    List<String> matching() => [
      for (final p in _catalogue)
        if (matchedGiftInterests(p, {GiftInterest.accessories}).isNotEmpty)
          p.id,
    ];
    expect(GiftInterest.accessories.label, 'Accessories');
    expect(matching(), [
      'clip', // Accessories category
      'belt',
      'xmas-bag',
      'kids-acc', // Baby & Kids > Accessories
      'pricey-bag',
    ]);
  });

  test('budget and interests stay strict with the new options; the occasion '
      'only reorders', () {
    final results = recommendGifts(
      products: _catalogue,
      recipient: GiftRecipient.anyone,
      occasion: GiftOccasion.christmas,
      budget: GiftBudget.under250,
      interests: {GiftInterest.accessories},
    );
    final ids = results.map((r) => r.product.id).toList();
    // Never the over-budget handbag, hair oil or the ring.
    expect(ids.toSet(), {'clip', 'belt', 'xmas-bag', 'kids-acc'});
    // The festive piece leads, and says why.
    expect(ids.first, 'xmas-bag');

    final plain = recommendGifts(
      products: _catalogue,
      recipient: GiftRecipient.anyone,
      occasion: GiftOccasion.justBecause,
      budget: GiftBudget.under250,
      interests: {GiftInterest.accessories},
    );
    expect(plain.map((r) => r.product.id).toSet(), ids.toSet());
  });

  test('without an interest, an occasion match explains itself', () {
    final results = recommendGifts(
      products: _catalogue,
      recipient: GiftRecipient.anyone,
      occasion: GiftOccasion.christmas,
      budget: GiftBudget.under250,
    );
    expect(results.first.product.id, 'xmas-bag');
    expect(results.first.reason, 'A festive Christmas pick');
    expect(results, hasLength(6));
  });

  testWidgets('the finder offers and uses the new occasion and interest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          giftCatalogueProvider.overrideWith((ref) async => _catalogue),
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

    expect(find.text("Mother's Day"), findsOneWidget);
    expect(find.text('New baby'), findsOneWidget);
    await tap('Anyone');
    await tap('Christmas');
    await tap('Under R250');
    await tap('Accessories');
    await tester.tap(find.byKey(const Key('gift-finder-submit')));
    await tester.pump();
    await tester.pump();

    final cards = find.descendant(
      of: find.byKey(const Key('gift-finder-matches')),
      matching: find.byType(GiftResultCard),
    );
    expect(cards, findsNWidgets(4));
    expect(find.text('Hair oil'), findsNothing);
    // The over-budget handbag is only ever a labelled close match.
    expect(
      find.descendant(
        of: find.byKey(const Key('gift-finder-matches')),
        matching: find.text('Leather handbag'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('gift-finder-close-matches')),
        matching: find.text('Leather handbag'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
