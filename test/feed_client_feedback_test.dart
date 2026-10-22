import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/feed_preferences.dart';
import 'package:artisanal_lane/features/buyer/providers/feed_ranking.dart';
import 'package:artisanal_lane/features/buyer/providers/post_social_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/creator_feed_screen.dart';
import 'package:artisanal_lane/features/buyer/utils/feed_pagination.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_compose_button.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_feed/post_social_bar.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/models/category.dart';
import 'package:artisanal_lane/models/post_interaction.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/waveb_feed_fake_service.dart';

final _now = DateTime(2026, 10, 22, 12);

ShopPost _post(
  String id, {
  String shopId = 'shop-a',
  Duration age = Duration.zero,
  List<String> productIds = const [],
}) => ShopPost(
  id: id,
  shopId: shopId,
  shopName: 'Maker $shopId',
  caption: 'Post $id',
  productIds: productIds,
  createdAt: _now.subtract(age),
  updatedAt: _now.subtract(age),
);

/// Server-side feed, newest first, served with the same keyset semantics
/// as `FeedCursor.olderThanFilter` (published_at desc, id desc).
List<ShopPost> _serveAfter(List<ShopPost> server, FeedCursor? cursor, int n) {
  final sorted = [...server]
    ..sort((a, b) {
      final byTime = b.publishedAt.compareTo(a.publishedAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
  final older = cursor == null
      ? sorted
      : sorted.where((p) {
          final byTime = p.publishedAt.compareTo(cursor.publishedAt);
          return byTime < 0 || (byTime == 0 && p.id.compareTo(cursor.id) < 0);
        });
  return older.take(n).toList();
}

class _Social implements PostSocialRepository {
  _Social(this.linked);
  final List<Product> linked;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<PostEngagement> engagement(String id) async =>
      const PostEngagement(likes: 0, comments: 0, liked: false);
  @override
  Future<List<Product>> products(String postId) async => linked;
}

Product _product(String id, {String title = 'Ochre Mug', double price = 320}) =>
    Product(
      id: id,
      shopId: 'shop-a',
      title: title,
      price: price,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('feed pagination never repeats a post', () {
    test('keyset paging stays correct when a post is published mid-scroll', () {
      final server = [
        for (var i = 0; i < 6; i++)
          _post('p$i', age: Duration(hours: i + 1)),
      ];
      final loaded = <ShopPost>[];
      var page = _serveAfter(server, null, 3);
      appendUniquePosts(loaded, page);
      var cursor = FeedCursor.after(page);

      // A maker publishes while the buyer scrolls: with offset paging the
      // next page (offset 3) would start with p2 again.
      server.add(_post('fresh'));

      page = _serveAfter(server, cursor, 3);
      appendUniquePosts(loaded, page);
      cursor = FeedCursor.after(page);
      expect(loaded.map((p) => p.id), ['p0', 'p1', 'p2', 'p3', 'p4', 'p5']);
      expect(_serveAfter(server, cursor, 3), isEmpty);
    });

    test('appendUniquePosts drops overlap from an offset-shifted page', () {
      final loaded = [_post('a'), _post('b'), _post('c')];
      final added = appendUniquePosts(loaded, [
        _post('c'),
        _post('d'),
        _post('d'),
      ]);
      expect(added.map((p) => p.id), ['d']);
      expect(loaded.map((p) => p.id), ['a', 'b', 'c', 'd']);
    });

    test('dedupePostsById keeps the first occurrence', () {
      expect(
        dedupePostsById([_post('x'), _post('y'), _post('x')]).map((p) => p.id),
        ['x', 'y'],
      );
    });

    test('cursor filter quotes the timestamp and id for PostgREST', () {
      final cursor = FeedCursor(
        publishedAt: DateTime.utc(2026, 10, 22, 9, 30, 1, 123, 456),
        id: 'abc',
      );
      expect(
        cursor.olderThanFilter,
        'published_at.lt."2026-10-22T09:30:01.123456Z",'
        'and(published_at.eq."2026-10-22T09:30:01.123456Z",id.lt."abc")',
      );
      expect(FeedCursor.after(const []), isNull);
    });
  });

  group('For you ranks page by page', () {
    test('a newly loaded page never moves posts already shown', () {
      final page1 = [
        _post('old-1', shopId: 's1', age: const Duration(days: 3)),
        _post('old-2', shopId: 's2', age: const Duration(days: 4)),
      ];
      // Page 2 holds a post from a followed maker that outscores page 1.
      final page2 = [
        _post('followed', shopId: 'loved', age: const Duration(days: 5)),
      ];
      final signals = FeedRankingSignals(
        followedShopIds: const {'loved'},
        now: _now,
      );
      final pageOf = {
        for (final p in page1) p.id: 0,
        for (final p in page2) p.id: 1,
      };

      final before = rankForYouFeedByPage(page1, pageOf, signals);
      final after = rankForYouFeedByPage([...page1, ...page2], pageOf, signals);
      expect(
        after.take(before.length).map((p) => p.id),
        before.map((p) => p.id),
      );
      expect(after.last.id, 'followed');
      // Whole-list ranking (the old behaviour) would have jumped it to the top.
      expect(rankForYouFeed([...page1, ...page2], signals).first.id, 'followed');
    });

    test('never returns the same post twice', () {
      final posts = [_post('a'), _post('b', shopId: 'shop-b'), _post('a')];
      final ranked = rankForYouFeedByPage(
        posts,
        const {},
        FeedRankingSignals(now: _now),
      );
      expect(ranked.map((p) => p.id).toSet().length, ranked.length);
      expect(ranked.length, 2);
    });
  });

  group('Shop this piece', () {
    testWidgets('a linked product shows a tappable chip that opens it', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: PostSocialBar(post: _post('p1', productIds: ['mug'])),
            ),
          ),
          GoRoute(
            path: '/home/product/:id',
            builder: (_, state) =>
                Text('Product page ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('buyer'),
            supabaseServiceProvider.overrideWithValue(FakeSupabaseService()),
            postSocialRepositoryProvider.overrideWithValue(
              _Social([_product('mug')]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shop this piece'), findsOneWidget);
      expect(find.text('Ochre Mug'), findsOneWidget);
      expect(find.textContaining('320'), findsOneWidget);
      await tester.tap(find.byKey(const Key('post-product-chip-mug')));
      await tester.pumpAndSettle();
      expect(find.text('Product page mug'), findsOneWidget);
    });

    testWidgets('no chip when the post links nothing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('buyer'),
            supabaseServiceProvider.overrideWithValue(FakeSupabaseService()),
            postSocialRepositoryProvider.overrideWithValue(_Social(const [])),
          ],
          child: MaterialApp(
            home: Scaffold(body: PostSocialBar(post: _post('p1'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shop this piece'), findsNothing);
    });
  });

  group('Feed create pill', () {
    testWidgets('buyers see "Sell", a finished sheet, then the application', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: CreatorComposeButton(onFinished: () async {})),
          ),
          GoRoute(
            path: '/vendor/apply',
            builder: (_, _) => const Scaffold(body: Text('Application form')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('buyer'),
            vendorShopProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sell'), findsOneWidget);
      expect(find.byTooltip('Sell on Artisan Lane'), findsOneWidget);
      await tester.tap(find.text('Sell'));
      await tester.pumpAndSettle();
      expect(find.text('Sell on Artisan Lane'), findsWidgets);
      expect(find.text('What are you creating?'), findsNothing);
      expect(find.text('Not now'), findsOneWidget);
      await tester.tap(find.byKey(const Key('start-selling-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Application form'), findsOneWidget);
    });

    testWidgets('guests see no create pill', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserIdProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: Scaffold(
              body: CreatorComposeButton(onFinished: () async {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-create-button')), findsNothing);
    });
  });

  group('Tune your feed sheet', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('explains itself, has no Discover detour, toggles flip', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('buyer'),
            supabaseServiceProvider.overrideWithValue(FakeSupabaseService()),
            categoriesProvider.overrideWith(
              (ref) async => [
                Category(
                  id: 'ceramics',
                  name: 'Ceramics',
                  slug: 'ceramics',
                  createdAt: DateTime(2026),
                ),
              ],
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: Scaffold(
                  body: TuneYourFeedSheet(makers: {'shop-a': 'Clay & Co'}),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tune your feed'), findsOneWidget);
      expect(find.text('Refine in Discover'), findsNothing);
      expect(
        find.textContaining('Turn a maker off to see fewer of their posts'),
        findsOneWidget,
      );
      expect(find.text('Showing as usual'), findsOneWidget);
      final toggle = find.byKey(const Key('shape-feed-mute-shop-a'));
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(find.text('Showing fewer posts'), findsOneWidget);
      expect(
        container.read(feedPreferencesProvider).value!.mutedShopIds,
        {'shop-a'},
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(
        container.read(feedPreferencesProvider).value!.mutedShopIds,
        isEmpty,
      );

      await tester.tap(find.byKey(const Key('shape-feed-category-ceramics')));
      await tester.pumpAndSettle();
      expect(
        container.read(feedPreferencesProvider).value!.boostedCategoryIds,
        {'ceramics'},
      );
    });
  });
}
