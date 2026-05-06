import 'package:artisanal_lane/services/push_notifications_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message notification data routes to the buyer chat thread', () {
    expect(
      routeForPushNotification({
        'type': 'chat_message',
        'thread_id': 'thread-123',
        'recipient_role': 'buyer',
      }),
      '/profile/messages/thread-123',
    );
  });

  test('message notification data routes to the vendor chat thread', () {
    expect(
      routeForPushNotification({
        'type': 'chat_message',
        'thread_id': 'thread-456',
        'recipient_role': 'vendor',
      }),
      '/vendor/messages/thread-456',
    );
  });

  test('unknown notification data does not route', () {
    expect(routeForPushNotification({'type': 'unknown'}), isNull);
    expect(
      routeForPushNotification({
        'type': 'chat_message',
        'thread_id': '',
        'recipient_role': 'buyer',
      }),
      isNull,
    );
  });
}
