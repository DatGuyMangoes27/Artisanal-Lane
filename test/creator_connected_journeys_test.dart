import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/creator_shop_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/discovery_preferences.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:artisanal_lane/features/buyer/widgets/shop_product_tile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Preferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async =>
      const DiscoveryPreferences(maxBudget: 500, skippedProductIds: {'skip'});
}

class _UnrestrictedPreferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async => const DiscoveryPreferences();
}

final _products = [
  for (final id in ['bowl', 'skip', 'vase'])
    Product(
      id: id,
      shopId: 'maker',
      title: 'Handmade $id with a long title',
      shopName: 'An independent maker',
      price: id == 'vase' ? 800 : 300,
      images: const [''],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
];

void main() {
  testWidgets('short and long titles keep photos and prices aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentFavouriteIdsProvider.overrideWithValue(const [])],
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final title in [
                  'Bowl',
                  'A very long handmade product name spanning two lines',
                ])
                  SizedBox(
                    width: 150,
                    height: 290,
                    child: ShopProductTile(
                      product: Product(
                        id: title,
                        shopId: 'maker',
                        title: title,
                        shopName: 'Maker',
                        price: 123.45,
                        images: const [''],
                        createdAt: DateTime(2026),
                        updatedAt: DateTime(2026),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final photos = find.byType(CachedNetworkImage);
    expect(tester.getSize(photos.at(0)), tester.getSize(photos.at(1)));
    final prices = find.text('R123.45');
    expect(
      tester.getTopLeft(prices.at(0)).dy,
      tester.getTopLeft(prices.at(1)).dy,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'editorial Shop fits a narrow phone and opens its actual product',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const CreatorShopScreen()),
          GoRoute(
            path: '/home/product/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Selected ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            categoryProductsProvider.overrideWith(
              (ref, filter) async => _products,
            ),
            cartItemsProvider.overrideWith((ref) async => <CartItem>[]),
            discoveryPreferencesProvider.overrideWith(
              _UnrestrictedPreferences.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('THE ARTISAN EDIT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('THE ARTISAN EDIT'));
      await tester.pumpAndSettle();
      expect(find.text('Selected bowl'), findsOneWidget);
    },
  );

  test('Discover choices drive For you without hiding the full catalogue', () {
    const preferences = DiscoveryPreferences(
      maxBudget: 500,
      skippedProductIds: {'skip'},
    );
    expect(
      filterCreatorShopProducts(
        products: _products,
        query: '',
        filter: CreatorShopFilter.forYou,
        preferences: preferences,
      ).map((p) => p.id),
      ['bowl'],
    );
    expect(
      filterCreatorShopProducts(
        products: _products,
        query: '',
        filter: CreatorShopFilter.allPieces,
        preferences: preferences,
      ),
      hasLength(3),
    );
  });

  testWidgets(
    'complete compact Shop connects to Discover and retains catalogue access',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const CreatorShopScreen()),
          GoRoute(
            path: '/discover',
            builder: (_, __) => const Scaffold(body: Text('Taste builder')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            categoryProductsProvider.overrideWith(
              (ref, filter) async => _products,
            ),
            cartItemsProvider.overrideWith((ref) async => <CartItem>[]),
            discoveryPreferencesProvider.overrideWith(_Preferences.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shop the lane'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Artisans'), findsOneWidget);
      expect(find.text('Handmade bowl with a long title'), findsOneWidget);
      expect(find.text('Handmade vase with a long title'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Rows'));
      await tester.tap(find.byTooltip('Rows'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ShopProductTile>(find.byType(ShopProductTile).first).row,
        isTrue,
      );
      await tester.tap(find.byTooltip('One card'));
      await tester.pumpAndSettle();
      expect(
        (tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        1,
      );
      await tester.tap(find.byTooltip('Two cards'));
      await tester.pumpAndSettle();
      expect(
        (tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Your taste'));
      await tester.tap(find.text('Your taste'));
      await tester.pumpAndSettle();
      expect(find.text('Taste builder'), findsOneWidget);
    },
  );
}
