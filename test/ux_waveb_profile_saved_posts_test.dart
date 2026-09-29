// Coverage for SavedPostsScreen (lib/features/buyer/screens/
// saved_posts_screen.dart): the empty state when nothing is saved, and the
// 3-column grid + working unsave when posts are saved.
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/creator_parity_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/saved_posts_screen.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ShopPost _post(String id) {
  final now = DateTime(2026, 5, 3, 18);
  return ShopPost(
    id: id,
    shopId: 'shop-1',
    caption: 'Post $id',
    mediaUrls: const ['https://example.com/photo.jpg'],
    createdAt: now,
    updatedAt: now,
    shopName: 'Thando Made',
  );
}

void main() {
  testWidgets('shows the empty state when nothing is saved', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'buyer-1'),
          savedPostsProvider.overrideWith((ref) async => const <ShopPost>[]),
          savedPostIdsProvider.overrideWith(
            () => OptimisticIdSet(
              (ref) async => <String>{},
              (ref, id, on) async {},
            ),
          ),
        ],
        child: const MaterialApp(home: SavedPostsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('Save posts to find them here.'), findsOneWidget);
  });

  testWidgets('shows a 3-column grid of saved posts and unsave removes one', (
    tester,
  ) async {
    final posts = [_post('post-1'), _post('post-2'), _post('post-3')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'buyer-1'),
          savedPostsProvider.overrideWith((ref) async => posts),
          savedPostIdsProvider.overrideWith(
            () => OptimisticIdSet(
              (ref) async => {'post-1', 'post-2', 'post-3'},
              (ref, id, on) async {},
            ),
          ),
        ],
        child: const MaterialApp(home: SavedPostsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final grid = tester.widget<GridView>(find.byType(GridView));
    final gridDelegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(gridDelegate.crossAxisCount, 3);
    final itemDelegate = grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(itemDelegate.childCount, posts.length);
    expect(find.bySemanticsLabel('Unsave this post'), findsNWidgets(3));

    await tester.tap(find.bySemanticsLabel('Unsave this post').first);
    await tester.pump();

    // Unsaving updates savedPostIdsProvider, which the grid filters by, so
    // the tile disappears without waiting for a refetch.
    final updatedGrid = tester.widget<GridView>(find.byType(GridView));
    final updatedDelegate =
        updatedGrid.childrenDelegate as SliverChildBuilderDelegate;
    expect(updatedDelegate.childCount, posts.length - 1);
  });
}
