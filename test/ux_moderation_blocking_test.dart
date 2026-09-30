// Blocking and takedown handling: the blocked-accounts screen, hidden
// comments, the comment menu, chat composer replacement, and the maker's
// "Removed by Artisan Lane" banner. Nothing here touches the network.
import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/blocking_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/creator_parity_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/post_social_providers.dart';
import 'package:artisanal_lane/features/buyer/screens/blocked_accounts_screen.dart';
import 'package:artisanal_lane/features/buyer/screens/post_comments_screen.dart';
import 'package:artisanal_lane/features/buyer/widgets/removed_post_banner.dart';
import 'package:artisanal_lane/features/chat/widgets/chat_block_bar.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/models/post_interaction.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Social implements PostSocialRepository {
  _Social(this.rows, {this.rejectSend = false});
  final List<PostComment> rows;
  final bool rejectSend;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<PostEngagement> engagement(String id) async =>
      PostEngagement(likes: 0, comments: rows.length, liked: false);
  @override
  Future<List<PostComment>> comments(String id, {PostComment? before}) async =>
      List.of(rows);
  @override
  Future<void> addComment(String post, String body, String requestId) async {
    if (rejectSend) {
      throw const PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
    }
  }
}

PostComment _comment(String id, String userId, String author) => PostComment(
  id: id,
  userId: userId,
  body: 'Body of $id',
  author: author,
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
);

List<dynamic> _commentOverrides(
  _Social social,
  Set<String> blocked,
  List<bool> saves,
) => [
  currentUserIdProvider.overrideWithValue('me'),
  vendorShopProvider.overrideWith((ref) async => null),
  postSocialRepositoryProvider.overrideWithValue(social),
  blockedUserIdsProvider.overrideWith(
    () => OptimisticIdSet((ref) async => blocked, (ref, id, on) async {
      saves.add(on);
    }),
  ),
];

void main() {
  test('ShopPost parses takedown fields and builds the banner copy', () {
    final base = {
      'id': 'p',
      'shop_id': 's',
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
    };
    expect(ShopPost.fromJson(base).isRemoved, isFalse);
    final removed = ShopPost.fromJson({
      ...base,
      'removed_at': '2026-09-02T10:00:00Z',
      'removed_reason': 'Counterfeit item',
    });
    expect(removed.isRemoved, isTrue);
    expect(removed.removedMessage, 'Removed by Artisan Lane: Counterfeit item');
    expect(
      ShopPost.fromJson({
        ...base,
        'removed_at': '2026-09-02T10:00:00Z',
      }).removedMessage,
      'Removed by Artisan Lane',
    );
  });

  test('permission rejections are recognised', () {
    expect(
      isPermissionRejection(
        const PostgrestException(message: 'nope', code: '42501'),
      ),
      isTrue,
    );
    expect(isPermissionRejection(StateError('network timeout')), isFalse);
  });

  testWidgets('removed banner shows the reason', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RemovedPostBanner.message('Removed by Artisan Lane: Spam'),
        ),
      ),
    );
    expect(find.text('Removed by Artisan Lane: Spam'), findsOneWidget);
  });

  testWidgets('chat bars show the right copy and unblock', (tester) async {
    var unblocked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBlockBar.blocked(onUnblock: () => unblocked++),
        ),
      ),
    );
    expect(find.text("You've blocked this person"), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    expect(unblocked, 1);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatBlockBar.cannotReply())),
    );
    expect(find.text("You can't reply to this conversation"), findsOneWidget);
    expect(find.text('Unblock'), findsNothing);
  });

  testWidgets('blocked accounts lists people and unblocks optimistically', (
    tester,
  ) async {
    final saves = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('me'),
          blockedUserIdsProvider.overrideWith(
            () => OptimisticIdSet(
              (ref) async => {'u1', 'u2'},
              (ref, id, on) async => saves.add(on),
            ),
          ),
          blockedProfilesProvider.overrideWith(
            (ref) async => [
              (id: 'u1', name: 'Sipho', avatarUrl: null),
              (id: 'u2', name: 'Anele', avatarUrl: null),
            ],
          ),
        ],
        child: const MaterialApp(home: BlockedAccountsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sipho'), findsOneWidget);
    expect(find.text('Anele'), findsOneWidget);
    await tester.tap(find.text('Unblock').first);
    await tester.pumpAndSettle();
    expect(saves, [false]);
    expect(find.text('Unblock'), findsOneWidget);
  });

  testWidgets('blocked accounts empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('me'),
          blockedUserIdsProvider.overrideWith(
            () =>
                OptimisticIdSet((ref) async => <String>{}, (a, b, c) async {}),
          ),
          blockedProfilesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: BlockedAccountsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nobody blocked'), findsOneWidget);
  });

  testWidgets('comments from blocked people are hidden', (tester) async {
    final social = _Social([
      _comment('c1', 'friend', 'Thandi'),
      _comment('c2', 'troll', 'Rude Person'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _commentOverrides(social, {'troll'}, []).cast(),
        child: const MaterialApp(
          home: PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Body of c1'), findsOneWidget);
    expect(find.text('Body of c2'), findsNothing);
  });

  testWidgets('comment menu blocks after confirming in the sheet', (
    tester,
  ) async {
    final saves = <bool>[];
    final social = _Social([_comment('c1', 'friend', 'Thandi')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _commentOverrides(social, <String>{}, saves).cast(),
        child: const MaterialApp(
          home: PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Comment options'));
    await tester.pumpAndSettle();
    expect(find.text('Block Thandi'), findsOneWidget);
    await tester.tap(find.text('Block Thandi'));
    await tester.pumpAndSettle();
    expect(find.textContaining("They won't be notified"), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Block Thandi'));
    await tester.pumpAndSettle();
    expect(saves, [true]);
    expect(find.text('Body of c1'), findsNothing);
  });

  testWidgets('a rejected comment explains the block', (tester) async {
    final social = _Social(const [], rejectSend: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _commentOverrides(social, <String>{}, []).cast(),
        child: const MaterialApp(
          home: PostCommentsScreen(postId: 'post', shopId: 'shop'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();
    expect(find.text(blockedCommentMessage), findsOneWidget);
  });
}
