import 'package:artisanal_lane/app/buyer_routes.dart';
import 'package:artisanal_lane/app/tab_reselect.dart';
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart'
    show currentProfileProvider;
import 'package:artisanal_lane/features/buyer/providers/blocking_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/front_page_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/front_page_screen.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:artisanal_lane/widgets/buyer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _now = DateTime(2026, 10, 20);

Product _product(String id, String title, {bool featured = false}) => Product(
  id: id,
  shopId: 'maker-$id',
  title: title,
  price: 350,
  stockQty: 2,
  images: const [''],
  shopName: 'Maker $id',
  isFeatured: featured,
  createdAt: _now,
  updatedAt: _now,
);

Shop _shop(String id, String name, {String? cover, String? location}) => Shop(
  id: id,
  vendorId: 'vendor-$id',
  name: name,
  slug: id,
  coverImageUrl: cover,
  location: location,
  createdAt: _now,
  updatedAt: _now,
);

ShopPost _post(String id, String shopId, String caption) => ShopPost(
  id: id,
  shopId: shopId,
  caption: caption,
  shopName: 'Studio $shopId',
  createdAt: _now,
  updatedAt: _now,
);

Widget _placeholder(GoRouterState state) =>
    Scaffold(body: Center(child: Text('screen:${state.uri.path}')));

Future<GoRouter> _pumpFrontPage(
  WidgetTester tester, {
  List<Product> newArrivals = const [],
  List<Product> featured = const [],
  List<Shop> spotlight = const [],
  List<Shop> shops = const [],
  List<ShopPost> posts = const [],
  Set<String> hiddenShopIds = const {},
  FrontPageSeason? season,
  double width = 412,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 3200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: frontPageRoute,
    routes: [
      GoRoute(
        path: frontPageRoute,
        builder: (_, __) => const FrontPageScreen(),
      ),
      for (final path in [
        '/feed',
        '/cart',
        '/home/shop-all',
        '/home/shops',
        '/home/curated',
        '/home/gift-concierge',
        '/home/product/:id',
        '/home/shop/:id',
      ])
        GoRoute(path: path, builder: (_, state) => _placeholder(state)),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        currentProfileProvider.overrideWith((ref) async => null),
        cartItemsProvider.overrideWith((ref) async => <CartItem>[]),
        hiddenShopIdsProvider.overrideWithValue(hiddenShopIds),
        freshArrivalsProvider.overrideWith((ref) async => newArrivals),
        featuredProductsProvider.overrideWith((ref) async => featured),
        spotlightShopsProvider.overrideWith((ref) async => spotlight),
        shopsProvider.overrideWith((ref) async => shops),
        frontPageLatestPostsProvider.overrideWith((ref) async => posts),
        frontPageSeasonProvider.overrideWithValue(season),
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
  return router;
}

Future<void> _pumpFullFrontPage(
  WidgetTester tester, {
  FrontPageSeason? season,
  double width = 412,
  double textScale = 1,
}) => _pumpFrontPage(
  width: width,
  textScale: textScale,
  tester,
  newArrivals: [_product('n1', 'Woven basket'), _product('n2', 'Clay mug')],
  featured: [
    _product('f1', 'Beaded necklace', featured: true),
    _product('f2', 'Linen throw', featured: true),
  ],
  spotlight: [
    _shop('s1', 'Karoo Clay', location: 'Graaff-Reinet'),
    _shop('s2', 'Indigo Loom'),
  ],
  posts: [
    _post('p1', 's1', 'Fresh from the kiln this morning'),
    _post('p2', 's2', 'New indigo dye batch'),
    _post('p3', 'muted', 'You should not see this'),
    _post('p4', 's1', 'Glazing day'),
    _post('p5', 's2', 'One post too many'),
  ],
  hiddenShopIds: const {'muted'},
  season: season,
);

void main() {
  group('front page sections', () {
    testWidgets('renders every section, in order, from real data', (
      tester,
    ) async {
      await _pumpFullFrontPage(tester);

      expect(find.text('WELCOME TO ARTISAN LANE'), findsOneWidget);
      expect(find.text('Handmade, close to home'), findsOneWidget);
      expect(find.byTooltip('Cart'), findsOneWidget);

      // Hero: the newest featured piece, in the everyday Artisan edit look.
      expect(find.byKey(const Key('front-hero')), findsOneWidget);
      expect(find.text('THE ARTISAN EDIT'), findsOneWidget);
      expect(find.text('Maker f1'), findsWidgets);

      expect(find.text('New arrivals'), findsOneWidget);
      expect(find.text('Woven basket'), findsOneWidget);
      expect(find.text('Clay mug'), findsOneWidget);

      // The hero product is not repeated in the Artisan edit row.
      expect(find.text('The Artisan edit'), findsOneWidget);
      expect(find.byKey(const ValueKey('front-product-f1')), findsNothing);
      expect(find.byKey(const ValueKey('front-product-f2')), findsOneWidget);

      expect(find.text('Artisan spotlight'), findsOneWidget);
      expect(find.text('Karoo Clay'), findsOneWidget);
      expect(find.text('Graaff-Reinet'), findsOneWidget);
      expect(find.text('Indigo Loom'), findsOneWidget);

      expect(find.byKey(const Key('front-gift-finder')), findsOneWidget);

      // Latest three posts, skipping muted/blocked makers.
      expect(find.text('From the makers'), findsOneWidget);
      expect(find.text('Fresh from the kiln this morning'), findsOneWidget);
      expect(find.text('New indigo dye batch'), findsOneWidget);
      expect(find.text('Glazing day'), findsOneWidget);
      expect(find.text('You should not see this'), findsNothing);
      expect(find.text('One post too many'), findsNothing);

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final order = [
        top(find.text('Handmade, close to home')),
        top(find.byKey(const Key('front-hero'))),
        top(find.byKey(const Key('front-new-arrivals'))),
        top(find.byKey(const Key('front-artisan-edit'))),
        top(find.byKey(const Key('front-spotlight'))),
        top(find.byKey(const Key('front-gift-finder'))),
        top(find.byKey(const Key('front-from-makers'))),
      ];
      expect(order, [...order]..sort());
    });

    testWidgets('lays out on a small phone with large text', (tester) async {
      await _pumpFullFrontPage(tester, width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.text('Artisan spotlight'), findsOneWidget);
      expect(find.text('Glazing day'), findsOneWidget);
    });

    testWidgets('hides sections that have nothing to show', (tester) async {
      await _pumpFrontPage(tester);

      expect(find.text('Handmade, close to home'), findsOneWidget);
      expect(find.byKey(const Key('front-hero')), findsNothing);
      expect(find.text('New arrivals'), findsNothing);
      expect(find.text('The Artisan edit'), findsNothing);
      expect(find.text('Artisan spotlight'), findsNothing);
      expect(find.text('From the makers'), findsNothing);
      // The gift finder never depends on data.
      expect(find.byKey(const Key('front-gift-finder')), findsOneWidget);
    });

    testWidgets('spotlight falls back to listed shops with cover photos', (
      tester,
    ) async {
      await _pumpFrontPage(
        tester,
        shops: [
          _shop('a', 'No Cover Studio'),
          _shop('b', 'Cover Studio', cover: 'https://example.com/c.jpg'),
        ],
      );
      expect(find.text('Artisan spotlight'), findsOneWidget);
      expect(find.text('No Cover Studio'), findsNothing);
      expect(find.byKey(const ValueKey('front-shop-b')), findsOneWidget);
    });

    testWidgets('seasonal hook restyles the hero without new content', (
      tester,
    ) async {
      await _pumpFullFrontPage(
        tester,
        season: const FrontPageSeason(
          eyebrow: 'The test edit',
          headline: 'Seasonal\nheadline',
          background: Colors.black,
          accent: Colors.white,
        ),
      );
      expect(find.text('THE TEST EDIT'), findsOneWidget);
      expect(find.text('Seasonal\nheadline'), findsOneWidget);
      expect(find.text('THE ARTISAN EDIT'), findsNothing);
    });
  });

  group('front page links', () {
    Future<void> tapAndExpect(
      WidgetTester tester,
      Finder target,
      String screen,
    ) async {
      await _pumpFullFrontPage(tester);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('screen:$screen'), findsOneWidget);
    }

    testWidgets('new arrivals "See all" opens the newest-first catalogue', (
      tester,
    ) async {
      await tapAndExpect(
        tester,
        find.byKey(const Key('front-new-arrivals-see-all')),
        '/home/shop-all',
      );
    });

    testWidgets('Artisan edit "See all" opens the curated collection', (
      tester,
    ) async {
      await tapAndExpect(
        tester,
        find.byKey(const Key('front-artisan-edit-see-all')),
        '/home/curated',
      );
    });

    testWidgets('spotlight "See all" opens the artisans directory', (
      tester,
    ) async {
      await tapAndExpect(
        tester,
        find.byKey(const Key('front-spotlight-see-all')),
        '/home/shops',
      );
    });

    testWidgets('a spotlight card opens that shop', (tester) async {
      await tapAndExpect(
        tester,
        find.byKey(const ValueKey('front-shop-s1')),
        '/home/shop/s1',
      );
    });

    testWidgets('the hero opens its product', (tester) async {
      await tapAndExpect(
        tester,
        find.byKey(const Key('front-hero')),
        '/home/product/f1',
      );
    });

    testWidgets('the gift card opens the gift finder', (tester) async {
      await tapAndExpect(
        tester,
        find.byKey(const Key('front-gift-finder')),
        '/home/gift-concierge',
      );
    });

    testWidgets('"From the makers" "See all" opens the Feed', (tester) async {
      await tapAndExpect(
        tester,
        find.byKey(const Key('front-from-makers-see-all')),
        '/feed',
      );
    });
  });

  group('front page helpers', () {
    test('greeting uses the first name when there is one', () {
      expect(frontPageGreeting('Nicky Smith'), 'Welcome back, Nicky');
      expect(frontPageGreeting('  '), 'Welcome to Artisan Lane');
      expect(frontPageGreeting(null), 'Welcome to Artisan Lane');
    });

    test('editorial falls back to the newest arrival for the hero', () {
      final result = frontPageEditorial(
        featured: const [],
        newArrivals: [_product('n1', 'Woven basket')],
      );
      expect(result.hero?.id, 'n1');
      expect(result.picks, isEmpty);
    });

    test('spotlight fallback keeps only shops with cover photos', () {
      final picked = spotlightFallbackShops([
        _shop('a', 'A'),
        _shop('b', 'B', cover: 'https://example.com/b.jpg'),
        _shop('c', 'C', cover: ' '),
      ]);
      expect(picked.map((shop) => shop.id), ['b']);
    });
  });

  group('buyer navigation', () {
    test('the creator app opens on the front page', () {
      expect(
        appInitialLocation(
          creatorCommerce: true,
          creatorCommercePreview: false,
        ),
        frontPageRoute,
      );
      expect(frontPageRoute, '/');
      expect(
        appInitialLocation(
          creatorCommerce: false,
          creatorCommercePreview: false,
        ),
        '/welcome',
      );
    });

    test('tabs are Home, Discover, Shop, Feed, You', () {
      expect(BuyerShell.creatorTabs, [
        BuyerTab.home,
        BuyerTab.discover,
        BuyerTab.shop,
        BuyerTab.feed,
        BuyerTab.you,
      ]);
    });

    testWidgets('bottom bar order, opening tab and branch switching', (
      tester,
    ) async {
      // A phone-sized screen (five tabs and the sign-in sheet).
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      StatefulShellBranch branch(String path) => StatefulShellBranch(
        routes: [
          GoRoute(path: path, builder: (_, state) => _placeholder(state)),
        ],
      );
      final router = GoRouter(
        initialLocation: appInitialLocation(
          creatorCommerce: true,
          creatorCommercePreview: false,
        ),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                BuyerShell(navigationShell: navigationShell),
            // Same order as the app router's branches.
            branches: [
              branch(frontPageRoute),
              branch('/discover'),
              branch(shopTabRoute),
              branch('/feed'),
              branch('/profile'),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartItemsProvider.overrideWith((ref) async => <CartItem>[]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((destination) => destination.label)
          .toList();
      // Guests see "Sign In" in the You slot.
      expect(labels, ['Home', 'Discover', 'Shop', 'Feed', 'Sign In']);

      expect(find.text('screen:/'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );

      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();
      expect(find.text('screen:/feed'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );

      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();
      expect(find.text('screen:/home'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('screen:/'), findsOneWidget);

      // The You tab still asks guests to sign in instead of opening.
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue'), findsOneWidget);
    });
  });
}
