import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/creator_shop_screen.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_commerce_header.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Product _product(
  String id,
  String title,
  double price, {
  bool featured = false,
}) => Product(
  id: id,
  shopId: 'shop-$id',
  title: title,
  price: price,
  isFeatured: featured,
  createdAt: DateTime(2026, 1, int.parse(id)),
  updatedAt: DateTime(2026),
);

void main() {
  test('shop filters use real catalogue properties', () {
    final products = [
      _product('1', 'Clay bowl', 720, featured: true),
      _product('2', 'Brass pin', 320),
      _product('3', 'New tote', 480),
    ];
    expect(
      filterCreatorShopProducts(
        products: products,
        query: '',
        filter: CreatorShopFilter.featured,
      ).map((p) => p.id),
      ['1'],
    );
    expect(
      filterCreatorShopProducts(
        products: products,
        query: 'tote',
        filter: CreatorShopFilter.underR500,
      ).map((p) => p.id),
      ['3'],
    );
    expect(
      filterCreatorShopProducts(
        products: products,
        query: '',
        filter: CreatorShopFilter.newDrops,
      ).first.id,
      '3',
    );
  });

  testWidgets('shared header fits compact width and exposes cart', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/feed',
      routes: [
        GoRoute(
          path: '/feed',
          builder: (_, __) => const Scaffold(
            body: CreatorCommerceHeader(
              eyebrow: 'Artisan Lane',
              title: 'Made with a story',
              subtitle: 'Updates shared directly by local makers.',
              cartCount: 2,
            ),
          ),
        ),
        GoRoute(path: '/cart', builder: (_, __) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer'),
          buyerUnreadThreadsCountProvider.overrideWithValue(3),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    expect(find.text('Made with a story'), findsOneWidget);
    expect(find.byTooltip('Cart'), findsOneWidget);
    expect(find.byTooltip('Messages'), findsOneWidget);
  });
}
