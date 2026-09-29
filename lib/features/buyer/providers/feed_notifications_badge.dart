import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'buyer_providers.dart';

/// Unread notification count for the feed/shop header's bell badge. Derives
/// from the same stream the notifications screen reads, so it stays in
/// sync without a second fetch.
final feedUnreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(notificationsStreamProvider).value ?? const [];
  return notifications.where((notification) => notification.isUnread).length;
});
