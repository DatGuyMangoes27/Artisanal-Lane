import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/post_social_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/post_comments_screen.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_feed/post_social_bar.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/widgets/post_product_picker.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_compose_button.dart';
import 'package:artisanal_lane/models/shop.dart';
import 'package:artisanal_lane/models/post_interaction.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeSocial implements PostSocialRepository {
  bool liked = false, failSend = false;
  final sentIds = <String>[];
  final rows = <PostComment>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<PostEngagement> engagement(String id) async =>
      PostEngagement(likes: liked ? 1 : 0, comments: rows.length, liked: liked);
  @override
  Future<void> setLiked(String id, bool value) async {
    liked = value;
  }

  @override
  Future<List<PostComment>> comments(String id, {PostComment? before}) async =>
      List.of(rows);
  @override
  Future<void> addComment(String post, String body, String requestId) async {
    sentIds.add(requestId);
    // Simulate a committed write whose response was lost.
    if (!rows.any((c) => c.id == requestId)) {
      rows.insert(
        0,
        PostComment(
          id: requestId,
          userId: 'buyer',
          body: body,
          author: 'Buyer',
          createdAt: DateTime.now(),
        ),
      );
    }
    if (failSend) {
      failSend = false;
      throw StateError('network timeout');
    }
  }

  @override
  Future<void> editComment(String id, String body) async {
    final i = rows.indexWhere((c) => c.id == id),
        old = rows.firstWhere((c) => c.id == id);
    rows[i] = PostComment(
      id: id,
      userId: old.userId,
      body: body,
      author: old.author,
      createdAt: old.createdAt,
      edited: true,
    );
  }

  @override
  Future<void> deleteComment(String id) async {
    rows.removeWhere((c) => c.id == id);
  }
}

final post = ShopPost(
  id: 'post',
  shopId: 'shop',
  caption: 'Made by hand',
  productIds: ['piece'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
Product piece(String id) => Product(
  id: id,
  shopId: 'shop',
  title: 'Piece $id',
  price: 349,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('New post connects the Feed straight to the post editor route', (
    tester,
  ) async {
    final shop = Shop(
      id: 'shop',
      vendorId: 'maker',
      name: 'Maker',
      slug: 'maker',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: CreatorComposeButton(onFinished: () async {})),
        ),
        GoRoute(
          path: '/create/post',
          builder: (_, _) =>
              const Scaffold(body: Text('Real post editor route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('maker'),
          vendorShopProvider.overrideWith((ref) async => shop),
          vendorSubscriptionProvider.overrideWith((ref) async => null),
          vendorPayoutProfileProvider.overrideWith((ref) async => null),
          vendorSubscriptionStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
          vendorPayoutProfileStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    // Makers with a shop see a labelled "New post" pill that opens the
    // composer directly, with no intermediate sheet.
    expect(find.text('New post'), findsOneWidget);
    await tester.tap(find.text('New post'));
    await tester.pumpAndSettle();
    expect(find.text('Real post editor route'), findsOneWidget);
  });
  testWidgets('comment composer stays within a narrow keyboard viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer'),
          vendorShopProvider.overrideWith((ref) async => null),
          postSocialRepositoryProvider.overrideWithValue(FakeSocial()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 250)),
            child: child!,
          ),
          home: const PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'A longer comment\nwith several lines\nabout this lovely\nhandmade piece.',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'likes persist through repository and tagged product opens actual route',
    (tester) async {
      final repository = FakeSocial();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: PostSocialBar(post: post)),
          ),
          GoRoute(
            path: '/home/product/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Product ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('buyer'),
            postSocialRepositoryProvider.overrideWithValue(repository),
            postProductsProvider(
              'post',
            ).overrideWith((ref) async => [piece('piece')]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Like post'));
      await tester.pumpAndSettle();
      expect(repository.liked, isTrue);
      expect(find.byTooltip('Unlike post'), findsOneWidget);
      await tester.tap(find.byTooltip('Unlike post'));
      await tester.pumpAndSettle();
      expect(repository.liked, isFalse);
      await tester.tap(find.text('Piece piece'));
      await tester.pumpAndSettle();
      expect(find.text('Product piece'), findsOneWidget);
    },
  );
  testWidgets(
    'failed comment retry preserves text and request id; editing and deleting work',
    (tester) async {
      final repository = FakeSocial()..failSend = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('buyer'),
            vendorShopProvider.overrideWith((ref) async => null),
            postSocialRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: PostCommentsScreen(postId: 'post', shopId: 'shop'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Lovely craftsmanship');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      // The failed draft stays visible both as an optimistic (failed) comment
      // and as editable text in the composer, so the user can edit or resend it.
      expect(find.text('Lovely craftsmanship'), findsNWidgets(2));
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(repository.sentIds.length, 2);
      expect(repository.sentIds.toSet().length, 1);
      expect(repository.rows.length, 1);
      expect(find.text('Lovely craftsmanship'), findsOneWidget);
      await tester.tap(find.byTooltip('Comment options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Beautiful texture');
      await tester.tap(find.byTooltip('Save comment'));
      await tester.pumpAndSettle();
      expect(find.text('Beautiful texture'), findsOneWidget);
      expect(repository.rows.single.edited, isTrue);
      await tester.tap(find.byTooltip('Comment options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.rows, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('guest can read comments but has no composer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          postSocialRepositoryProvider.overrideWithValue(FakeSocial()),
        ],
        child: const MaterialApp(
          home: PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to comment'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets('artisan product picker searches and returns selected real ids', (
    tester,
  ) async {
    var selected = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorProductsProvider.overrideWith(
            (ref) async => [piece('a'), piece('b')],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PostProductPicker(
                ids: selected,
                onChanged: (ids) => setState(() => selected = ids),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose products (0/5)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Piece b');
    await tester.pumpAndSettle();
    expect(find.text('Piece a'), findsNothing);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Piece b'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(selected, ['b']);
    expect(find.byType(InputChip), findsOneWidget);
  });
}
