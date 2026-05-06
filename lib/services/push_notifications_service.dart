import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'supabase_service.dart';

String? routeForPushNotification(Map<String, dynamic> data) {
  final type = data['type']?.toString();
  final threadId = data['thread_id']?.toString().trim();
  final recipientRole = data['recipient_role']?.toString();

  if (type != 'chat_message' || threadId == null || threadId.isEmpty) {
    return null;
  }

  if (recipientRole == 'vendor') {
    return '/vendor/messages/$threadId';
  }

  if (recipientRole == 'buyer') {
    return '/profile/messages/$threadId';
  }

  return null;
}

class PushNotificationsService {
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'artisan_lane_push',
        'Artisan Lane notifications',
        description: 'Messages, order updates, and dispute notifications.',
        importance: Importance.max,
      );

  PushNotificationsService({
    required SupabaseService supabaseService,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _supabaseService = supabaseService,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final SupabaseService _supabaseService;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  Future<void> initialize({
    required FutureOr<void> Function(String route) onOpenRoute,
  }) async {
    if (kIsWeb) return;

    await _requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _initializeLocalNotifications(onOpenRoute);

    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _openMessage(message, onOpenRoute),
    );
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_openMessage(initialMessage, onOpenRoute));
    }
  }

  Future<void> registerCurrentDevice() async {
    if (kIsWeb) return;

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _supabaseService.registerPushToken(
          token: token,
          platform: _platformName,
        );
      } catch (_) {
        // A transient network issue should not block app startup.
      }
    }

    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      if (token.isEmpty) return;
      unawaited(_registerRefreshedToken(token));
    });
  }

  Future<void> revokeCurrentDevice() async {
    if (kIsWeb) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await _supabaseService.revokePushToken(token);
    } catch (_) {
      // Sign-out should continue even if the revoke call cannot reach Supabase.
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _registerRefreshedToken(String token) async {
    try {
      await _supabaseService.registerPushToken(
        token: token,
        platform: _platformName,
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _openMessage(
    RemoteMessage message,
    FutureOr<void> Function(String route) onOpenRoute,
  ) async {
    final route = routeForPushNotification(message.data);
    if (route == null) return;
    await onOpenRoute(route);
  }

  Future<void> _initializeLocalNotifications(
    FutureOr<void> Function(String route) onOpenRoute,
  ) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map) return;
          final route = routeForPushNotification(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (route != null) {
            unawaited(Future.sync(() => onOpenRoute(route)));
          }
        } catch (_) {
          return;
        }
      },
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(_androidChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'artisan_lane_push',
        'Artisan Lane notifications',
        channelDescription:
            'Messages, order updates, and dispute notifications.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: Color(0xFF8B1E13),
      ),
    );

    await _localNotifications.show(
      id: (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch)
          .abs(),
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  String get _platformName {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'unknown';
  }
}
