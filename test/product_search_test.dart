import 'dart:async';

import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/creator_shop_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/discovery_preferences.dart';
import 'package:artisanal_lane/features/buyer/utils/product_search.dart';
import 'package:artisanal_lane/features/buyer/widgets/shop_product_tile.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Product _p(
  String id,
  String title, {
  String? description,
  String? shop,
  List<String> tags = const [],
  String? category,
  String? subcategory,
}) => Product(
  id: id,
  shopId: 'shop-$id',
  title: title,
  description: description,
  shopName: shop,
  tags: tags,
  categoryName: category,
  subcategoryName: subcategory,
  price: 120,
  images: const [''],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// Newest first, as the server returns them: the irrelevant pieces come
// first so ordering by relevance is actually tested.
final _catalogue = [
  _p(
    'santa',
    'Santa tree hanger – white',
    description: 'Hangs from strings on your tree.',
    shop: 'KnitbyNic',
  ),
  _p(
    'hoops',
    'Sweet Panda Hoops',
    description: 'Cute clay earrings.',
    shop: 'h.of.clay',
    category: 'Jewellery',
    subcategory: 'Earrings',
  ),
  _p(
    'sunflower',
    'Sunflower soul',
    description: 'Pairs well with a necklace or two.',
    shop: 'Vintage Art Bottles',
  ),
  _p('spring', 'Spring wreath', shop: 'Bloom'),
  _p(
    'pendant',
    'Copper Pendant Necklace',
    shop: 'Copper & Co',
    category: 'Jewellery',
    subcategory: 'Necklaces',
  ),
  _p(
    'silver',
    'Silver Stacking Ring',
    shop: 'Copper & Co',
    category: 'Jewellery',
    subcategory: 'Rings',
  ),
  _p('moon', 'Moon band', tags: const ['rings', 'moon'], shop: 'Luna'),
  _p('towel', 'Tea towel', shop: 'Rings by Lu'),
];

List<String> _ids(List<Product> products) => [for (final p in products) p.id];

void main() {
  group('product search matching', () {
    test('plurals and prefixes match, substrings inside words do not', () {
      expect(matchSearchWord('rings', ['ring']), SearchWordMatch.exact);
      expect(matchSearchWord('ring', ['rings']), SearchWordMatch.exact);
      expect(matchSearchWord('neckla', ['necklace']), SearchWordMatch.prefix);
      expect(matchSearchWord('rings', ['earrings']), SearchWordMatch.none);
      expect(matchSearchWord('rings', ['strings']), SearchWordMatch.none);
      expect(matchSearchWord('ring', ['spring']), SearchWordMatch.none);
      expect(matchSearchWord('boxes', ['box']), SearchWordMatch.exact);
      expect(
        matchSearchWord('accessories', ['accessory']),
        SearchWordMatch.exact,
      );
      expect(singularSearchWord('glass'), 'glass');
      expect(singularSearchWord('cactus'), 'cactus');
    });

    test('words split on punctuation and ignore case', () {
      expect(searchWords('Santa tree-hanger – WHITE'), [
        'santa',
        'tree',
        'hanger',
        'white',
      ]);
      expect(searchQueryWords('  Ring ring  '), ['ring']);
      expect(searchQueryWords('%,()'), isEmpty);
    });

    test('"rings" drops strings/earrings and ranks title > tags > shop', () {
      expect(_ids(rankProductSearch(_catalogue, 'rings')), [
        'silver',
        'moon',
        'towel',
      ]);
    });

    test('"neckla" puts the necklace before description-only matches', () {
      expect(_ids(rankProductSearch(_catalogue, 'neckla')), [
        'pendant',
        'sunflower',
      ]);
    });

    test('every query word has to match somewhere', () {
      expect(_ids(rankProductSearch(_catalogue, 'copper ring')), ['silver']);
      expect(_ids(rankProductSearch(_catalogue, 'copper necklace')), [
        'pendant',
      ]);
      expect(rankProductSearch(_catalogue, 'necklace dragon'), isEmpty);
    });

    test('category and subcategory names count as metadata matches', () {
      final jewellery = _ids(rankProductSearch(_catalogue, 'jewellery'));
      expect(jewellery.toSet(), {'hoops', 'pendant', 'silver'});
      expect(_ids(rankProductSearch(_catalogue, 'earrings')), ['hoops']);
    });

    test('ties keep the incoming (newest first) order', () {
      final a = _p('a', 'Clay mug');
      final b = _p('b', 'Clay mug');
      expect(_ids(rankProductSearch([a, b], 'mug')), ['a', 'b']);
      expect(_ids(rankProductSearch([b, a], 'mug')), ['b', 'a']);
    });

    test('empty query matches nothing', () {
      expect(rankProductSearch(_catalogue, '   '), isEmpty);
      expect(productSearchScore(_catalogue.first, ''), 0);
    });

    test('catalogue filter uses the same word matching', () {
      expect(
        _ids(
          filterCreatorShopProducts(
            products: _catalogue,
            query: 'rings',
            filter: CreatorShopFilter.allPieces,
          ),
        ).toSet(),
        {'silver', 'moon', 'towel'},
      );
    });
  });

  testWidgets(
    'typing keeps the search field, its focus and text while results load',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final searched = <String>[];
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const CreatorShopScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            currentFavouriteIdsProvider.overrideWithValue(const []),
            categoryProductsProvider.overrideWith(
              (ref, filter) async => _catalogue,
            ),
            shopSearchProductsProvider.overrideWith((ref, query) async {
              searched.add(query);
              await Future<void>.delayed(const Duration(milliseconds: 500));
              return rankProductSearch(_catalogue, query);
            }),
            cartItemsProvider.overrideWith((ref) async => <CartItem>[]),
            discoveryPreferencesProvider.overrideWith(_NoPreferences.new),
            recentSearchesProvider.overrideWith(_NoRecentSearches.new),
            trendingSearchesProvider.overrideWith(
              (ref) => Stream.value(const <String>[]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('shop-search-field'));
      await tester.showKeyboard(field);
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final focusNode = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;

      // Type "neckla" a letter at a time, pausing longer than the debounce
      // between some letters so searches fire mid-typing.
      const word = 'neckla';
      for (var i = 1; i <= word.length; i++) {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: word.substring(0, i),
            selection: TextSelection.collapsed(offset: i),
          ),
        );
        await tester.pump(
          i.isEven
              ? CreatorShopScreen.searchDebounce +
                    const Duration(milliseconds: 50)
              : const Duration(milliseconds: 120),
        );
        // Same field element, still focused, text intact, no full-screen
        // skeleton or "0 pieces" flash.
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(editable),
        );
        expect(focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(
          tester.widget<TextField>(field).controller!.text,
          word.substring(0, i),
        );
        expect(find.text('0 pieces'), findsNothing);
      }

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);
      expect(find.text('Results for "neckla"'), findsOneWidget);
      expect(find.text('2 pieces'), findsOneWidget);
      // Debounced: far fewer searches than keystrokes, last one is the
      // full word.
      expect(searched.length, lessThan(word.length));
      expect(searched.last, 'neckla');
      final tiles = tester
          .widgetList<ShopProductTile>(find.byType(ShopProductTile))
          .map((tile) => tile.product.id)
          .toList();
      expect(tiles, ['pendant', 'sunflower']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quick links and filter chips are never truncated at 1.15x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, __) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.15)),
            child: const CreatorShopScreen(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          currentFavouriteIdsProvider.overrideWithValue(const []),
          categoryProductsProvider.overrideWith(
            (ref, filter) async => _catalogue,
          ),
          cartItemsProvider.overrideWith((ref) async => <CartItem>[]),
          discoveryPreferencesProvider.overrideWith(_NoPreferences.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final screenWidth = tester.view.physicalSize.width;
    for (final label in ['Categories', 'Artisans', 'Your taste']) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      final rect = tester.getRect(text);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(screenWidth));
      // Not ellipsised: the laid-out paragraph fits its full label.
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse);
    }

    // Chip row scrolls sideways with edge padding: the first chip starts
    // inside the gutter, and every chip can be scrolled fully into view.
    final chips = find.byKey(const Key('shop-filter-chips'));
    expect(
      tester.getTopLeft(find.text('For you')).dx,
      greaterThanOrEqualTo(20),
    );
    for (final label in ['Under R500', 'Near me']) {
      await tester.dragUntilVisible(
        find.text(label),
        chips,
        const Offset(-80, 0),
      );
      await tester.pumpAndSettle();
      final chipRowRect = tester.getRect(chips);
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(chipRowRect.left));
      expect(rect.right, lessThanOrEqualTo(chipRowRect.right));
      expect(rect.top, greaterThanOrEqualTo(chipRowRect.top));
      expect(rect.bottom, lessThanOrEqualTo(chipRowRect.bottom));
    }
    expect(tester.takeException(), isNull);
  });
}

class _NoPreferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async => const DiscoveryPreferences();
}

class _NoRecentSearches extends RecentSearchesNotifier {
  @override
  Future<List<String>> build() async => const [];
}
