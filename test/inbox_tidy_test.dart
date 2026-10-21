import 'dart:async';

import 'package:artisanal_lane/features/buyer/providers/buyer_providers.dart';
import 'package:artisanal_lane/features/buyer/providers/feed_notifications_badge.dart';
import 'package:artisanal_lane/features/buyer/screens/notifications_screen.dart';
import 'package:artisanal_lane/features/chat/widgets/chat_widgets.dart';
import 'package:artisanal_lane/models/models.dart';
import 'package:artisanal_lane/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// In-memory notifications table. Each (re)subscription of the stream emits
/// the current rows, like the realtime stream's initial fetch.
class _FakeNotificationsService implements SupabaseService {
  _FakeNotificationsService(this.rows);

  final List<AppNotification> rows;
  final calls = <String>[];
  bool failWrites = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Stream<List<AppNotification>> stream() => Stream.value(
    rows.where((row) => !row.isDismissed).toList(growable: false),
  );

  void _update(
    bool Function(AppNotification) test,
    AppNotification Function(AppNotification) change,
  ) {
    for (var i = 0; i < rows.length; i++) {
      if (test(rows[i])) rows[i] = change(rows[i]);
    }
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    calls.add('read:$notificationId');
    _update(
      (row) => row.id == notificationId,
      (row) => row.copyWith(readAt: DateTime.now()),
    );
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    calls.add('readAll:$userId');
    _update(
      (row) => row.isUnread,
      (row) => row.copyWith(readAt: DateTime.now()),
    );
  }

  @override
  Future<void> dismissNotification(String notificationId) async {
    if (failWrites) throw StateError('offline');
    calls.add('dismiss:$notificationId');
    _update(
      (row) => row.id == notificationId,
      (row) => row.copyWith(dismissedAt: DateTime.now()),
    );
  }

  @override
  Future<void> dismissAllNotifications(String userId) async {
    calls.add('dismissAll:$userId');
    _update(
      (row) => !row.isDismissed,
      (row) => row.copyWith(dismissedAt: DateTime.now()),
    );
  }
}

AppNotification _notification(String id, String title, {bool read = false}) =>
    AppNotification(
      id: id,
      userId: 'buyer-1',
      title: title,
      body: 'Body for $title',
      notificationType: 'order_update',
      readAt: read ? DateTime.now().subtract(const Duration(hours: 1)) : null,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

ChatThread _thread(String id, String shopName, {DateTime? lastMessageAt}) =>
    ChatThread(
      id: id,
      shopId: 'shop-$id',
      buyerId: 'buyer-1',
      vendorId: 'vendor-$id',
      shopName: shopName,
      lastMessagePreview: 'New order placed',
      lastMessageAt: lastMessageAt ?? DateTime(2026, 10, 20, 9),
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 20, 9),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AppNotification', () {
    test('reads dismissed_at and treats it as cleared', () {
      final cleared = AppNotification.fromJson({
        'id': 'n1',
        'user_id': 'buyer-1',
        'title': 'Shipped',
        'created_at': '2026-10-20T08:00:00Z',
        'dismissed_at': '2026-10-21T08:00:00Z',
      });
      expect(cleared.isDismissed, isTrue);
      final open = AppNotification.fromJson({
        'id': 'n2',
        'user_id': 'buyer-1',
        'title': 'Shipped',
        'created_at': '2026-10-20T08:00:00Z',
      });
      expect(open.isDismissed, isFalse);
    });
  });

  group('Messages: delete a conversation', () {
    Future<List<ChatThread>> pump(
      WidgetTester tester,
      List<ChatThread> threads,
    ) async {
      final deleted = <ChatThread>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInboxList(
              threads: threads,
              showBuyerIdentity: false,
              emptyTitle: 'No conversations yet',
              emptySubtitle: 'Nothing here',
              onTap: (_) {},
              onDelete: (thread) async => deleted.add(thread),
            ),
          ),
        ),
      );
      return deleted;
    }

    const prompt =
        "It's removed from your messages. If they message you again, it will reappear.";

    testWidgets('swipe asks first and cancel keeps the conversation', (
      tester,
    ) async {
      final deleted = await pump(tester, [_thread('t1', 'Lobby Cape Town')]);
      await tester.drag(find.text('Lobby Cape Town'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete this conversation?'), findsOneWidget);
      expect(find.text(prompt), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleted, isEmpty);
      expect(find.text('Lobby Cape Town'), findsOneWidget);
    });

    testWidgets('swipe and confirm hides only that conversation', (
      tester,
    ) async {
      final deleted = await pump(tester, [
        _thread('t1', 'Lobby Cape Town'),
        _thread('t2', 'Karoo Clay'),
      ]);
      await tester.drag(find.text('Lobby Cape Town'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleted.map((t) => t.id), ['t1']);
      expect(find.text('Lobby Cape Town'), findsNothing);
      expect(find.text('Karoo Clay'), findsOneWidget);
    });

    testWidgets('long-press menu deletes after confirming', (tester) async {
      final deleted = await pump(tester, [_thread('t1', 'Lobby Cape Town')]);
      await tester.longPress(find.text('Lobby Cape Town'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();
      expect(find.text(prompt), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleted.map((t) => t.id), ['t1']);
      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('a newer message brings a deleted conversation back', (
      tester,
    ) async {
      await pump(tester, [_thread('t1', 'Lobby Cape Town')]);
      await tester.longPress(find.text('Lobby Cape Town'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Lobby Cape Town'), findsNothing);

      // The same list instance again (stale server data) stays hidden...
      await pump(tester, [_thread('t1', 'Lobby Cape Town')]);
      await tester.pumpAndSettle();
      expect(find.text('Lobby Cape Town'), findsNothing);

      // ...but a new message moves last_message_at and it reappears.
      await pump(tester, [
        _thread('t1', 'Lobby Cape Town', lastMessageAt: DateTime(2026, 10, 21)),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Lobby Cape Town'), findsOneWidget);
    });

    testWidgets('a failed delete puts the conversation back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInboxList(
              threads: [_thread('t1', 'Lobby Cape Town')],
              showBuyerIdentity: false,
              emptyTitle: 'No conversations yet',
              emptySubtitle: 'Nothing here',
              onTap: (_) {},
              onDelete: (_) async => throw StateError('offline'),
            ),
          ),
        ),
      );
      await tester.drag(find.text('Lobby Cape Town'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Lobby Cape Town'), findsOneWidget);
      expect(
        find.text("Couldn't delete the conversation. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets('without onDelete there is no swipe to delete', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInboxList(
              threads: [_thread('t1', 'Lobby Cape Town')],
              showBuyerIdentity: false,
              emptyTitle: 'No conversations yet',
              emptySubtitle: 'Nothing here',
              onTap: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(Dismissible), findsNothing);
    });
  });

  group('Notifications: filter, mark read and clear', () {
    late _FakeNotificationsService service;
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('buyer-1'),
          supabaseServiceProvider.overrideWithValue(service),
          notificationsStreamProvider.overrideWith((ref) => service.stream()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      service = _FakeNotificationsService([
        _notification('n1', 'Order shipped'),
        _notification('n2', 'New message'),
        _notification('n3', 'Review reminder', read: true),
      ]);
    });

    testWidgets('Unread shows only unread notifications', (tester) async {
      await pump(tester);
      expect(find.text('Review reminder'), findsOneWidget);
      expect(find.text('Unread (2)'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('notifications-filter-unread')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order shipped'), findsOneWidget);
      expect(find.text('New message'), findsOneWidget);
      expect(find.text('Review reminder'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('notifications-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Review reminder'), findsOneWidget);
    });

    testWidgets('Mark all as read updates the list and the badge', (
      tester,
    ) async {
      await pump(tester);
      expect(container.read(feedUnreadNotificationsCountProvider), 2);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(service.calls, ['readAll:buyer-1']);
      expect(container.read(feedUnreadNotificationsCountProvider), 0);
      expect(find.text('Unread'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('notifications-filter-unread')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("You're all caught up. No unread notifications."),
        findsOneWidget,
      );
    });

    testWidgets('Clear all asks first, then empties the list and badge', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all notifications?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      expect(find.text('Order shipped'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
      await tester.pumpAndSettle();

      expect(service.calls, ['dismissAll:buyer-1']);
      expect(find.text('No Notifications Yet'), findsOneWidget);
      expect(container.read(feedUnreadNotificationsCountProvider), 0);
    });

    testWidgets('swiping a notification clears just that one', (tester) async {
      await pump(tester);
      await tester.drag(find.text('Order shipped'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(service.calls, ['dismiss:n1']);
      expect(find.text('Order shipped'), findsNothing);
      expect(find.text('New message'), findsOneWidget);
      expect(container.read(feedUnreadNotificationsCountProvider), 1);
    });

    testWidgets('a failed swipe-clear puts the notification back', (
      tester,
    ) async {
      service.failWrites = true;
      await pump(tester);
      await tester.drag(find.text('Order shipped'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Order shipped'), findsOneWidget);
      expect(
        find.text("Couldn't clear that notification. Please try again."),
        findsOneWidget,
      );
    });
  });
}
