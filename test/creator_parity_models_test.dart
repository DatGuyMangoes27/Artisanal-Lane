import 'dart:convert';

import 'package:artisanal_lane/features/vendor/services/pending_post_store.dart';
import 'package:artisanal_lane/features/vendor/services/post_publication.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a scheduled poll post survives a restart unchanged', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PendingPostStore(await SharedPreferences.getInstance());
    final when = DateTime.utc(2026, 10, 1, 9);
    final submission = PostPublication(
      id: 'post-1',
      shopId: 'shop-1',
      caption: 'Which glaze?',
      mediaUrls: const ['https://example.com/a.jpg'],
      productIds: const ['p1'],
      commentsEnabled: false,
      hideLikeCount: true,
      scheduledFor: when,
      format: PostFormat.poll,
      poll: PollDraft(question: 'Which glaze next?', options: ['Blue', 'Rust']),
    );
    await store.save('user-1', submission);
    final restored = store.read('user-1')!;
    expect(restored.values, submission.values);
    expect(restored.format, PostFormat.poll);
    expect(restored.scheduledFor, when);
    expect(restored.poll!.options, ['Blue', 'Rust']);
    expect(submission.values.containsKey('poll'), isFalse);
  });

  test('submissions saved before the new settings still restore', () async {
    SharedPreferences.setMockInitialValues({
      'pending_post_submission_v1:user-1': jsonEncode({
        'id': 'old',
        'shop_id': 'shop-1',
        'caption': 'Hello',
        'media_urls': ['https://example.com/a.jpg'],
        'is_published': true,
      }),
    });
    final store = PendingPostStore(await SharedPreferences.getInstance());
    final restored = store.read('user-1')!;
    expect(restored.commentsEnabled, isTrue);
    expect(restored.format, PostFormat.photo);
    expect(restored.poll, isNull);
  });

  test('publish attaches the poll once the post is confirmed', () async {
    final attached = <PollDraft>[];
    final submission = PostPublication(
      id: 'post-1',
      shopId: 'shop-1',
      caption: '',
      mediaUrls: const ['m'],
      poll: PollDraft(question: 'Q', options: ['A', 'B']),
    );
    ShopPost? stored;
    await submission.publish(
      find: () async => stored,
      insert: (values) async => stored = ShopPost.fromJson({
        ...values,
        'created_at': '2026-09-28T10:00:00Z',
        'updated_at': '2026-09-28T10:00:00Z',
      }),
      attachPoll: (poll) async => attached.add(poll),
    );
    expect(attached.single.question, 'Q');
  });

  test('posts parse maker details and settings with safe defaults', () {
    final post = ShopPost.fromJson({
      'id': 'p',
      'shop_id': 's',
      'caption': 'x',
      'created_at': '2026-09-28T10:00:00Z',
      'updated_at': '2026-09-28T10:00:00Z',
      'shops': {
        'name': 'Clay',
        'is_verified': true,
        'location': 'Durban',
        'slug': 'clay',
      },
    });
    expect(post.shopIsVerified, isTrue);
    expect(post.shopHandle, 'clay');
    expect(post.commentsEnabled, isTrue);
    expect(post.format, PostFormat.photo);
    expect(post.publishedAt, post.createdAt);
    expect(post.isScheduled, isFalse);
  });

  test('poll results and insights parse server rows', () {
    final results = PollResults.fromRows([
      {'option_index': 1, 'votes': 3, 'my_vote': 1},
      {'option_index': 0, 'votes': 1, 'my_vote': 1},
    ]);
    expect(results.votes, [1, 3]);
    expect(results.total, 4);
    expect(results.myVote, 1);
    expect(results.share(1), 0.75);
    final insights = ShopInsights.fromJson({
      'days': 30,
      'post_views': 12,
      'likes': 4,
      'top_posts': [
        {'post_id': 'a', 'views': 9},
      ],
    });
    expect(insights.postViews, 12);
    expect(insights.comments, 0);
    expect(insights.topPosts.single.views, 9);
  });
}
