// Verifies the composer's new settings (comments, like-count visibility,
// schedule, format, step captions, poll) flow correctly into the existing
// PostPublication model that post_form_screen.dart builds when publishing.
import 'package:artisanal_lane/features/vendor/services/post_publication.dart';
import 'package:artisanal_lane/models/shop_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carries comments, like-count and schedule settings into values', () {
    final scheduledFor = DateTime.utc(2026, 2, 1, 9, 30);
    final submission = PostPublication(
      id: 'post-1',
      shopId: 'shop-1',
      caption: 'A new piece',
      mediaUrls: ['https://example.com/a.jpg'],
      commentsEnabled: false,
      hideLikeCount: true,
      scheduledFor: scheduledFor,
      format: PostFormat.carousel,
    );

    final values = submission.values;
    expect(values['comments_enabled'], isFalse);
    expect(values['hide_like_count'], isTrue);
    expect(values['scheduled_for'], scheduledFor.toUtc().toIso8601String());
    expect(values['format'], 'carousel');
  });

  test('defaults match the always-visible, unscheduled photo post', () {
    final submission = PostPublication(
      id: 'post-2',
      shopId: 'shop-1',
      caption: 'Default settings',
      mediaUrls: ['https://example.com/a.jpg'],
    );

    expect(submission.commentsEnabled, isTrue);
    expect(submission.hideLikeCount, isFalse);
    expect(submission.scheduledFor, isNull);
    expect(submission.format, PostFormat.photo);
    expect(submission.values['scheduled_for'], isNull);
  });

  test('carries tutorial step captions in submission order', () {
    final submission = PostPublication(
      id: 'post-3',
      shopId: 'shop-1',
      caption: 'How it is made',
      mediaUrls: ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
      format: PostFormat.tutorial,
      stepCaptions: ['Cut the brass', 'Polish it'],
    );

    expect(submission.values['step_captions'], ['Cut the brass', 'Polish it']);
    expect(submission.values['format'], 'tutorial');
  });

  test('poll draft is attached to the stored submission for safe retry', () {
    final poll = PollDraft(
      question: 'Which colour next?',
      options: ['Terracotta', 'Ochre'],
      closesAt: DateTime.utc(2026, 2, 8),
    );
    final submission = PostPublication(
      id: 'post-4',
      shopId: 'shop-1',
      caption: 'Vote below',
      mediaUrls: ['https://example.com/poll.jpg'],
      format: PostFormat.poll,
      poll: poll,
    );

    final stored = submission.stored;
    expect(stored['poll'], {
      'question': 'Which colour next?',
      'options': ['Terracotta', 'Ochre'],
      'closes_at': '2026-02-08T00:00:00.000Z',
    });

    // Round-trips through the pending-post store's persistence shape.
    final restored = PostPublication.fromStored(stored);
    expect(restored.poll?.question, poll.question);
    expect(restored.poll?.options, poll.options);
    expect(restored.format, PostFormat.poll);
  });

  test('round-trips every new setting through fromStored', () {
    final submission = PostPublication(
      id: 'post-5',
      shopId: 'shop-1',
      caption: 'Restore me',
      mediaUrls: ['https://example.com/a.jpg'],
      commentsEnabled: false,
      hideLikeCount: true,
      scheduledFor: DateTime.utc(2026, 3, 1, 8),
      format: PostFormat.video,
    );

    final restored = PostPublication.fromStored(submission.stored);
    expect(restored.commentsEnabled, isFalse);
    expect(restored.hideLikeCount, isTrue);
    expect(restored.scheduledFor, submission.scheduledFor);
    expect(restored.format, PostFormat.video);
  });
}
