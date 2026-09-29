import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/feed_notifications_badge.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppNotification notification(String id, {DateTime? readAt}) =>
      AppNotification(
        id: id,
        userId: 'buyer-1',
        title: 'New post',
        body: 'A maker you follow posted something new.',
        notificationType: 'post',
        readAt: readAt,
        createdAt: DateTime(2026, 9, 28),
      );

  test('is zero when there are no notifications', () {
    final container = ProviderContainer(
      overrides: [
        notificationsStreamProvider.overrideWith(
          (ref) => Stream.value(const <AppNotification>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(feedUnreadNotificationsCountProvider), 0);
  });

  test('updates once the stream emits unread notifications', () async {
    final container = ProviderContainer(
      overrides: [
        notificationsStreamProvider.overrideWith(
          (ref) => Stream.value([
            notification('1'),
            notification('2', readAt: DateTime(2026, 9, 27)),
            notification('3'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      feedUnreadNotificationsCountProvider,
      (_, __) {},
    );
    // Let the stream's first event land.
    await Future<void>.delayed(Duration.zero);
    expect(sub.read(), 2);
  });
}
