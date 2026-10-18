import 'package:artisanal_lane/features/auth/providers/auth_providers.dart';
import 'package:artisanal_lane/features/buyer/widgets/creator_feed/post_poll_card.dart';
import 'package:artisanal_lane/features/vendor/providers/vendor_providers.dart';
import 'package:artisanal_lane/features/vendor/services/post_publication.dart';
import 'package:artisanal_lane/features/vendor/widgets/composer/composer_poll_editor.dart';
import 'package:artisanal_lane/features/vendor/widgets/composer/composer_schedule_section.dart';
import 'package:artisanal_lane/models/creator_parity.dart';
import 'package:artisanal_lane/models/product.dart';
import 'package:artisanal_lane/models/shop.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/waveb_feed_fake_service.dart';

final _now = DateTime(2026, 10, 18, 12);

ShopPost _post({
  String id = 'poll-post',
  List<String> media = const [],
  DateTime? scheduledFor,
  PostFormat format = PostFormat.poll,
}) => ShopPost(
  id: id,
  shopId: 'shop-1',
  shopName: 'Clay & Co',
  caption: '',
  mediaUrls: media,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  scheduledFor: scheduledFor,
  format: format,
);

Widget _pollHarness(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    home: Scaffold(body: PostPollCard(post: _post())),
  ),
);

FakeSupabaseService _pollService({List<int> votes = const [1, 1]}) =>
    FakeSupabaseService()
      ..pollByPostId['poll-post'] = const PostPoll(
        postId: 'poll-post',
        question: 'Favourite glaze?',
        options: ['Matte', 'Gloss'],
      )
      ..pollResultsByPostId['poll-post'] = PollResults(votes: votes);

void main() {
  group('poll creation', () {
    test('a scheduled poll closes relative to its go-live time', () {
      final goLive = _now.add(const Duration(days: 2));
      expect(
        composerPollClosesAt(
          duration: const Duration(days: 1),
          scheduledFor: goLive,
          now: _now,
        ),
        goLive.add(const Duration(days: 1)),
      );
    });

    test('an immediate poll closes relative to now; no end means null', () {
      expect(
        composerPollClosesAt(duration: const Duration(days: 3), now: _now),
        _now.add(const Duration(days: 3)),
      );
      expect(composerPollClosesAt(duration: null, now: _now), isNull);
    });

    test('duplicate options are rejected', () {
      expect(
        composerPollError(
          question: 'Which glaze?',
          options: const ['Blue', ' blue '],
          imageCount: 1,
        ),
        'Each poll option needs to be different.',
      );
    });

    test('the poll draft is resumed exactly after a restart', () {
      final closes = DateTime.utc(2026, 10, 21, 10);
      final publication = PostPublication(
        id: 'post-1',
        shopId: 'shop-1',
        caption: '',
        mediaUrls: const ['https://example.com/a.jpg'],
        format: PostFormat.poll,
        poll: PollDraft(
          question: 'Which glaze?',
          options: const ['Blue', 'Green'],
          closesAt: closes,
        ),
      );
      final restored = PostPublication.fromStored(publication.stored);
      expect(restored.format, PostFormat.poll);
      expect(restored.poll!.question, 'Which glaze?');
      expect(restored.poll!.options, ['Blue', 'Green']);
      expect(restored.poll!.closesAt, closes);
    });
  });

  group('poll status line', () {
    const open = PostPoll(postId: 'p', question: 'Q', options: ['A', 'B']);
    test('open poll without votes invites the first vote', () {
      expect(
        pollStatusLabel(poll: open, totalVotes: 0, now: _now),
        'Be the first to vote',
      );
    });
    test('the maker sees a plain count on their own poll', () {
      expect(
        pollStatusLabel(poll: open, totalVotes: 0, isOwner: true, now: _now),
        '0 votes',
      );
    });
    test('shows time left until the poll closes', () {
      final poll = PostPoll(
        postId: 'p',
        question: 'Q',
        options: const ['A', 'B'],
        closesAt: _now.add(const Duration(hours: 30)),
      );
      expect(
        pollStatusLabel(poll: poll, totalVotes: 1, now: _now),
        '1 vote · Ends in 1d',
      );
    });
    test('closed polls say so and keep the final count', () {
      final poll = PostPoll(
        postId: 'p',
        question: 'Q',
        options: const ['A', 'B'],
        closesAt: _now.subtract(const Duration(minutes: 1)),
      );
      expect(
        pollStatusLabel(poll: poll, totalVotes: 7, now: _now),
        'Poll closed · 7 votes',
      );
    });
  });

  group('voting', () {
    testWidgets('a vote is replaced by the live server tally', (tester) async {
      final service = _pollService(votes: [1, 1]);
      await tester.pumpWidget(
        _pollHarness([
          currentUserIdProvider.overrideWithValue('buyer-1'),
          supabaseServiceProvider.overrideWithValue(service),
        ]),
      );
      await tester.pumpAndSettle();
      // Someone else votes for Gloss while this buyer is looking.
      service.pollResultsByPostId['poll-post'] = const PollResults(
        votes: [1, 2],
      );
      await tester.tap(find.text('Matte'));
      await tester.pumpAndSettle();
      expect(service.voteCalls, [('poll-post', 0)]);
      // Server truth after the vote: Matte 2, Gloss 2.
      expect(find.text('50% · 2'), findsNWidgets(2));
      expect(find.text('4 votes'), findsOneWidget);
    });

    testWidgets('changing a vote moves it to the new option', (tester) async {
      final service = _pollService(votes: [1, 1]);
      await tester.pumpWidget(
        _pollHarness([
          currentUserIdProvider.overrideWithValue('buyer-1'),
          supabaseServiceProvider.overrideWithValue(service),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Matte'));
      await tester.pumpAndSettle();
      expect(find.text('67% · 2'), findsOneWidget);
      await tester.tap(find.text('Gloss'));
      await tester.pumpAndSettle();
      expect(service.voteCalls, [('poll-post', 0), ('poll-post', 1)]);
      expect(find.text('33% · 1'), findsOneWidget);
      expect(find.text('67% · 2'), findsOneWidget);
      expect(find.text('3 votes'), findsOneWidget);
    });

    testWidgets('the maker sees results but cannot vote in their own poll', (
      tester,
    ) async {
      final service = _pollService(votes: [3, 1]);
      final shop = Shop(
        id: 'shop-1',
        vendorId: 'maker-1',
        name: 'Clay & Co',
        slug: 'clay-co',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        _pollHarness([
          currentUserIdProvider.overrideWithValue('maker-1'),
          supabaseServiceProvider.overrideWithValue(service),
          vendorShopProvider.overrideWith((ref) async => shop),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('75% · 3'), findsOneWidget);
      await tester.tap(find.text('Gloss'));
      await tester.pumpAndSettle();
      expect(service.voteCalls, isEmpty);
    });
  });

  group('scheduling', () {
    test('a future schedule hides the post and shows it once due', () {
      final scheduled = _post(
        format: PostFormat.photo,
        scheduledFor: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(scheduled.isScheduled, isTrue);
      expect(scheduled.publishedAt, scheduled.scheduledFor);
      final due = _post(
        format: PostFormat.photo,
        scheduledFor: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(due.isScheduled, isFalse);
    });

    test('published_at from the server orders the feed', () {
      final post = ShopPost.fromJson({
        'id': 'p1',
        'shop_id': 's1',
        'created_at': '2026-10-01T08:00:00Z',
        'updated_at': '2026-10-01T08:00:00Z',
        'scheduled_for': '2026-10-05T08:00:00Z',
        'published_at': '2026-10-05T08:00:00Z',
      });
      expect(post.publishedAt, DateTime.utc(2026, 10, 5, 8));
    });

    test('editing a live post never re-schedules it', () {
      final live = composerEditedSchedule(
        original: _now.subtract(const Duration(days: 1)),
        edited: _now.subtract(const Duration(days: 1)),
        now: _now,
      );
      expect(live.change, isFalse);
      expect(
        composerEditedSchedule(original: null, edited: null, now: _now).change,
        isFalse,
      );
    });

    test('a still-scheduled post can move or go live now', () {
      final original = _now.add(const Duration(days: 1));
      final moved = _now.add(const Duration(days: 2));
      final move = composerEditedSchedule(
        original: original,
        edited: moved,
        now: _now,
      );
      expect(move.change, isTrue);
      expect(move.value, moved);
      final postNow = composerEditedSchedule(
        original: original,
        edited: null,
        now: _now,
      );
      // Goes live at "now", so it lands at the top of the feed rather than
      // at its original creation time.
      expect(postNow.change, isTrue);
      expect(postNow.value, _now);
      expect(
        composerEditedSchedule(
          original: original,
          edited: original,
          now: _now,
        ).change,
        isFalse,
      );
    });
  });

  group('no stock imagery', () {
    test('posts without media have no image instead of a stock photo', () {
      expect(_post().primaryImage, isEmpty);
      expect(_post().coverImage, isEmpty);
    });

    test('cover image skips private video markers', () {
      final post = _post(
        media: const [
          'artisan-post://10000000-0000-0000-0000-000000000001/'
              '20000000-0000-0000-0000-000000000002.mp4',
          'https://example.com/photo.jpg',
        ],
      );
      expect(post.primaryImage, startsWith('artisan-post://'));
      expect(post.coverImage, 'https://example.com/photo.jpg');
    });

    test('products without photos have no image instead of a stock photo', () {
      final product = Product(
        id: 'p',
        shopId: 's',
        title: 'Bowl',
        price: 100,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(product.primaryImage, isEmpty);
    });
  });
}
