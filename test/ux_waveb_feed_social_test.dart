import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/creator_parity_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/feed_ranking.dart';
import 'package:artisanal_lane/features/buyer/providers/post_social_providers.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_feed/post_social_bar.dart';
import 'package:artisanal_lane/models/post_interaction.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/waveb_feed_fake_service.dart';

class _Social implements PostSocialRepository {
  _Social(this.likes);
  final int likes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<PostEngagement> engagement(String id) async =>
      PostEngagement(likes: likes, comments: 2, liked: false);
  @override
  Future<void> setLiked(String id, bool value) async {}
}

ShopPost _post({String id = 'p1', String shopId = 'shop-1'}) => ShopPost(
  id: id,
  shopId: shopId,
  shopName: 'Clay & Co',
  caption: 'Hi',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  hideLikeCount: true,
);

Widget _bar(FakeSupabaseService service, int likes, {String? user = 'u1'}) =>
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(user),
        supabaseServiceProvider.overrideWithValue(service),
        postSocialRepositoryProvider.overrideWithValue(_Social(likes)),
      ],
      child: MaterialApp(
        home: Scaffold(body: PostSocialBar(post: _post())),
      ),
    );

void main() {
  testWidgets('hidden like count shows no number and never a dash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bar(FakeSupabaseService(), hiddenLikeCountSentinel),
    );
    await tester.pumpAndSettle();
    expect(find.text('-1'), findsNothing);
    expect(find.text('–'), findsNothing);
    expect(find.text('2'), findsOneWidget); // comment count still shown
    expect(find.byTooltip('Like post'), findsOneWidget);
  });

  testWidgets('visible like count still renders (owner / not hidden)', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(FakeSupabaseService(), 12));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('tapping like on a hidden count keeps it hidden', (tester) async {
    await tester.pumpWidget(
      _bar(FakeSupabaseService(), hiddenLikeCountSentinel),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Like post'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unlike post'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('bookmark toggles saved state and persists via the service', (
    tester,
  ) async {
    final service = FakeSupabaseService();
    await tester.pumpWidget(_bar(service, 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save post'));
    await tester.pumpAndSettle();
    expect(service.saved, {'p1'});
    expect(find.byTooltip('Unsave post'), findsOneWidget);
    await tester.tap(find.byTooltip('Unsave post'));
    await tester.pumpAndSettle();
    expect(service.saved, isEmpty);
    expect(find.byTooltip('Save post'), findsOneWidget);
  });

  testWidgets('guest tapping save gets the sign-in prompt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = FakeSupabaseService();
    await tester.pumpWidget(_bar(service, 3, user: null));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save post'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to save posts'), findsOneWidget);
    expect(service.saved, isEmpty);
  });

  test('filterMutedPosts hides muted makers and keeps the rest', () {
    final posts = [
      _post(id: 'a', shopId: 's1'),
      _post(id: 'b', shopId: 's2'),
      _post(id: 'c', shopId: 's1'),
    ];
    expect(filterMutedPosts(posts, {'s1'}).map((p) => p.id), ['b']);
    expect(filterMutedPosts(posts, {}).length, 3);
  });

  test(
    'muting and unmuting updates mutedShopIdsProvider optimistically',
    () async {
      final service = FakeSupabaseService();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          supabaseServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      await container.read(mutedShopIdsProvider.future);
      final notifier = container.read(mutedShopIdsProvider.notifier);
      expect(await notifier.set('s1', true), isTrue);
      expect(container.read(isShopMutedProvider('s1')), isTrue);
      expect(service.muted, {'s1'});
      await notifier.set('s1', false);
      expect(container.read(isShopMutedProvider('s1')), isFalse);
    },
  );
}
