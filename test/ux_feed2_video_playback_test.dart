import 'package:artisanal_lane/features/buyer/providers/feed_video_playback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('visibleFraction', () {
    test('is 1.0 when the item fully fits inside the viewport', () {
      expect(
        visibleFraction(itemTop: 100, itemHeight: 200, viewportHeight: 800),
        1.0,
      );
    });

    test('is 0.0 when the item is entirely above the viewport', () {
      expect(
        visibleFraction(itemTop: -400, itemHeight: 200, viewportHeight: 800),
        0.0,
      );
    });

    test('is 0.0 when the item is entirely below the viewport', () {
      expect(
        visibleFraction(itemTop: 900, itemHeight: 200, viewportHeight: 800),
        0.0,
      );
    });

    test('is 0.5 when exactly half the item overlaps the bottom edge', () {
      expect(
        visibleFraction(itemTop: 700, itemHeight: 200, viewportHeight: 800),
        0.5,
      );
    });

    test('is 0.5 when exactly half the item overlaps the top edge', () {
      expect(
        visibleFraction(itemTop: -100, itemHeight: 200, viewportHeight: 800),
        0.5,
      );
    });

    test('is 0.0 for a zero-height item, never a divide-by-zero crash', () {
      expect(
        visibleFraction(itemTop: 100, itemHeight: 0, viewportHeight: 800),
        0.0,
      );
    });

    test('is 0.0 for a zero-height viewport', () {
      expect(
        visibleFraction(itemTop: 0, itemHeight: 200, viewportHeight: 0),
        0.0,
      );
    });
  });

  group('ActiveFeedVideoController', () {
    test('starts with no active video', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(activeFeedVideoPostIdProvider), isNull);
    });

    test('setActive updates state and is idempotent for the same id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var notifications = 0;
      container.listen(
        activeFeedVideoPostIdProvider,
        (_, __) => notifications++,
      );

      container
          .read(activeFeedVideoPostIdProvider.notifier)
          .setActive('post-1');
      expect(container.read(activeFeedVideoPostIdProvider), 'post-1');
      expect(notifications, 1);

      // Setting the same id again should not trigger another notification.
      container
          .read(activeFeedVideoPostIdProvider.notifier)
          .setActive('post-1');
      expect(notifications, 1);
    });

    test('only one post can be active at a time', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(activeFeedVideoPostIdProvider.notifier);
      notifier.setActive('post-1');
      notifier.setActive('post-2');
      expect(container.read(activeFeedVideoPostIdProvider), 'post-2');
    });

    test('clearIfActive only clears when it matches the active id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(activeFeedVideoPostIdProvider.notifier);
      notifier.setActive('post-1');

      notifier.clearIfActive('post-2');
      expect(container.read(activeFeedVideoPostIdProvider), 'post-1');

      notifier.clearIfActive('post-1');
      expect(container.read(activeFeedVideoPostIdProvider), isNull);
    });
  });

  group('FeedVideoMuteController', () {
    test('starts muted (no post ids unmuted)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container
            .read(feedVideoUnmutedPostIdsProvider.notifier)
            .isUnmuted('post-1'),
        isFalse,
      );
    });

    test('toggle unmutes then re-mutes a post independently of others', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(feedVideoUnmutedPostIdsProvider.notifier);

      notifier.toggle('post-1');
      expect(notifier.isUnmuted('post-1'), isTrue);
      expect(notifier.isUnmuted('post-2'), isFalse);

      notifier.toggle('post-1');
      expect(notifier.isUnmuted('post-1'), isFalse);
    });
  });
}
