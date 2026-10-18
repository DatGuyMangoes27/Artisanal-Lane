import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_feed/post_poll_card.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/models/creator_parity.dart';
import 'package:artisanal_lane/models/shop.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/waveb_feed_fake_service.dart';

final _post = ShopPost(
  id: 'poll-post',
  shopId: 'shop-1',
  shopName: 'Clay & Co',
  caption: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  format: PostFormat.poll,
);

Widget _harness({required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    home: Scaffold(body: PostPollCard(post: _post)),
  ),
);

void main() {
  testWidgets('guest tapping an option gets the sign-in prompt, no vote sent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = FakeSupabaseService()
      ..pollByPostId['poll-post'] = const PostPoll(
        postId: 'poll-post',
        question: 'Favourite glaze?',
        options: ['Matte', 'Gloss'],
      )
      ..pollResultsByPostId['poll-post'] = const PollResults(
        votes: [2, 3],
        myVote: null,
      );
    await tester.pumpWidget(
      _harness(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          supabaseServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Favourite glaze?'), findsOneWidget);
    expect(find.text('Matte'), findsOneWidget);
    await tester.tap(find.text('Matte'));
    await tester.pumpAndSettle();
    expect(find.text('Vote in this poll'), findsOneWidget);
    expect(service.voteCalls, isEmpty);
  });

  testWidgets(
    'voting shows optimistic percentage bars with the chosen option highlighted',
    (tester) async {
      final service = FakeSupabaseService()
        ..pollByPostId['poll-post'] = const PostPoll(
          postId: 'poll-post',
          question: 'Favourite glaze?',
          options: ['Matte', 'Gloss'],
        )
        ..pollResultsByPostId['poll-post'] = const PollResults(
          votes: [1, 1],
          myVote: null,
        );
      await tester.pumpWidget(
        _harness(
          overrides: [
            currentUserIdProvider.overrideWithValue('buyer-1'),
            supabaseServiceProvider.overrideWithValue(service),
          ],
        ),
      );
      await tester.pumpAndSettle();
      // Not voted yet: plain option rows, no percentages.
      expect(find.textContaining('%'), findsNothing);
      await tester.tap(find.text('Matte'));
      await tester.pump();
      // Optimistic update happens immediately, before the fake network call
      // resolves.
      expect(find.textContaining('67%'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(service.voteCalls, [('poll-post', 0)]);
      expect(find.textContaining('67%'), findsOneWidget);
    },
  );

  testWidgets('a failed vote rolls back the optimistic tally', (tester) async {
    final service = FakeSupabaseService()
      ..pollByPostId['poll-post'] = const PostPoll(
        postId: 'poll-post',
        question: 'Favourite glaze?',
        options: ['Matte', 'Gloss'],
      )
      ..pollResultsByPostId['poll-post'] = const PollResults(
        votes: [1, 1],
        myVote: null,
      )
      ..voteFails = true;
    await tester.pumpWidget(
      _harness(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer-1'),
          supabaseServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matte'));
    await tester.pumpAndSettle();
    // Rolled back to the unvoted state: plain option rows again.
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Matte'), findsOneWidget);
    expect(
      find.text("Couldn't record your vote. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('a closed poll shows results with a closed label and no voting', (
    tester,
  ) async {
    final service = FakeSupabaseService()
      ..pollByPostId['poll-post'] = PostPoll(
        postId: 'poll-post',
        question: 'Favourite glaze?',
        options: const ['Matte', 'Gloss'],
        closesAt: DateTime.now().subtract(const Duration(hours: 1)),
      )
      ..pollResultsByPostId['poll-post'] = const PollResults(
        votes: [4, 6],
        myVote: null,
      );
    await tester.pumpWidget(
      _harness(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer-1'),
          supabaseServiceProvider.overrideWithValue(service),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Poll closed · 10 votes'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
    await tester.tap(find.text('Matte'));
    await tester.pumpAndSettle();
    expect(service.voteCalls, isEmpty);
  });

  testWidgets(
    'the maker sees percentage bars on their own poll without voting',
    (tester) async {
      final service = FakeSupabaseService()
        ..pollByPostId['poll-post'] = const PostPoll(
          postId: 'poll-post',
          question: 'Favourite glaze?',
          options: ['Matte', 'Gloss'],
        )
        ..pollResultsByPostId['poll-post'] = const PollResults(
          votes: [3, 1],
          myVote: null,
        );
      final shop = Shop(
        id: 'shop-1',
        vendorId: 'maker-1',
        name: 'Clay & Co',
        slug: 'clay-co',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        _harness(
          overrides: [
            currentUserIdProvider.overrideWithValue('maker-1'),
            supabaseServiceProvider.overrideWithValue(service),
            vendorShopProvider.overrideWith((ref) async => shop),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('75%'), findsOneWidget);
    },
  );
}
