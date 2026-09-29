import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/discover_screen.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 22);
  Product product(String id, String title) => Product(
    id: id,
    shopId: 'maker',
    categoryId: 'home',
    title: title,
    price: 500,
    stockQty: 1,
    images: const [''],
    tags: const ['woven'],
    shopName: 'Test maker',
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpDiscover(
    WidgetTester tester, {
    required List<Product> products,
    Size size = const Size(412, 915),
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DiscoverScreen()),
        GoRoute(
          path: '/home/product/:id',
          builder: (_, state) => Scaffold(
            body: Center(child: Text('Detail ${state.pathParameters['id']}')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          discoverProductsProvider.overrideWith((ref) async => products),
          categoriesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a real Discover swipe advances to the next product', (
    tester,
  ) async {
    await pumpDiscover(
      tester,
      products: [
        product('one', 'First real piece'),
        product('two', 'Next real piece'),
      ],
    );

    expect(find.text('First real piece'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('discover-swipe-card')),
      const Offset(240, 8),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Next real piece'), findsOneWidget);
  });

  testWidgets('tapping a Discover product opens its product route', (
    tester,
  ) async {
    await pumpDiscover(tester, products: [product('detail-id', 'Tap me')]);

    await tester.tap(find.byKey(const Key('discover-swipe-card')));
    await tester.pumpAndSettle();

    expect(find.text('Detail detail-id'), findsOneWidget);
  });

  testWidgets('Discover has no layout exception on a narrow phone viewport', (
    tester,
  ) async {
    await pumpDiscover(
      tester,
      products: [product('narrow', 'Narrow screen piece')],
      size: const Size(320, 568),
    );

    expect(tester.takeException(), isNull);
  });
}
