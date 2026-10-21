import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/discover_feed_provider.dart';
import 'package:artisanal_lane/features/buyer/screens/discover_screen.dart';
import 'package:artisanal_lane/models/category.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 22);
  Product product(
    String id,
    String title, {
    String categoryId = 'home',
    double price = 500,
    DateTime? createdAt,
  }) => Product(
    id: id,
    shopId: 'maker',
    categoryId: categoryId,
    title: title,
    price: price,
    stockQty: 1,
    images: const [''],
    tags: const ['woven'],
    shopName: 'Test maker',
    createdAt: createdAt ?? now,
    updatedAt: now,
  );

  Future<void> pumpDiscover(
    WidgetTester tester, {
    required List<Product> products,
    List<Category> categories = const [],
    Size size = const Size(412, 915),
    double textScale = 1,
    void Function()? onFetch,
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
          discoverPageFetcherProvider.overrideWithValue(({
            required int offset,
            required int limit,
          }) async {
            onFetch?.call();
            return products.skip(offset).take(limit).toList();
          }),
          categoriesProvider.overrideWith((ref) async => categories),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('discover-swipe-card')),
      const Offset(240, 8),
    );
    await tester.pump(const Duration(milliseconds: 250));
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
    await swipeRight(tester);

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

  testWidgets('reaching the end keeps going with real pieces instead of '
      'stopping at "all caught up"', (tester) async {
    await pumpDiscover(
      tester,
      products: [
        product('one', 'First real piece'),
        product('two', 'Second real piece'),
      ],
    );

    await swipeRight(tester);
    await swipeRight(tester);

    expect(find.text("You're all caught up"), findsNothing);
    expect(find.byKey(const Key('discover-swipe-card')), findsOneWidget);
    expect(find.textContaining('another look'), findsOneWidget);

    // And it keeps going round, past the end of the recycled pass too.
    for (var i = 0; i < 3; i++) {
      await swipeRight(tester);
      expect(find.byKey(const Key('discover-swipe-card')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving preferences immediately refreshes the Discover deck', (
    tester,
  ) async {
    var fetches = 0;
    await pumpDiscover(
      tester,
      categories: [
        Category(id: 'home', name: 'Home', slug: 'home', createdAt: now),
        Category(
          id: 'jewellery',
          name: 'Jewellery',
          slug: 'jewellery',
          createdAt: now,
        ),
      ],
      products: [
        product(
          'vase',
          'Newest vase',
          createdAt: now.add(const Duration(days: 1)),
        ),
        product('ring', 'Silver ring', categoryId: 'jewellery'),
      ],
      onFetch: () => fetches++,
    );
    expect(find.text('Newest vase'), findsOneWidget);
    final fetchesBeforeSave = fetches;

    await tester.tap(find.text('Tune my preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jewellery'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discover-save-preferences')));
    await tester.pumpAndSettle();

    expect(find.text('Tune Discover'), findsNothing);
    expect(find.text('Silver ring'), findsOneWidget);
    expect(find.text('Newest vase'), findsNothing);
    expect(fetches, greaterThan(fetchesBeforeSave));
  });

  testWidgets('saving preferences after reaching the end changes the deck', (
    tester,
  ) async {
    await pumpDiscover(
      tester,
      categories: [
        Category(
          id: 'jewellery',
          name: 'Jewellery',
          slug: 'jewellery',
          createdAt: now,
        ),
      ],
      products: [
        product('a', 'Woven basket'),
        product('b', 'Clay bowl'),
        product('ring', 'Silver ring', categoryId: 'jewellery'),
      ],
    );
    for (var i = 0; i < 3; i++) {
      await swipeRight(tester);
    }
    expect(find.textContaining('another look'), findsOneWidget);

    await tester.tap(find.text('Tune my preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jewellery'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discover-save-preferences')));
    await tester.pumpAndSettle();

    // Recycling now leads with the newly preferred category.
    expect(find.text('Silver ring'), findsOneWidget);
  });

  testWidgets('"all caught up" only shows with no products, and its buttons '
      'do not clip at large text sizes', (tester) async {
    await pumpDiscover(tester, products: const [], textScale: 1.15);

    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('Show me everything'), findsOneWidget);
    expect(find.text('Adjust preferences'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final button = tester.getSize(
      find.ancestor(
        of: find.text('Adjust preferences'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final label = tester.getSize(find.text('Adjust preferences'));
    expect(button.height, greaterThan(label.height));
  });
}
