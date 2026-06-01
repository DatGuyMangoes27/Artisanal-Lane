import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/utils/auth_redirects.dart';
import 'features/buyer/providers/buyer_providers.dart';
import 'features/buyer/utils/payment_deep_links.dart';
import 'features/vendor/providers/vendor_providers.dart';
import 'services/meta_app_events_service.dart';
import 'services/push_notifications_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ArtisanalLaneApp()));
}

class ArtisanalLaneApp extends ConsumerStatefulWidget {
  const ArtisanalLaneApp({super.key});

  @override
  ConsumerState<ArtisanalLaneApp> createState() => _ArtisanalLaneAppState();
}

class _ArtisanalLaneAppState extends ConsumerState<ArtisanalLaneApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _paymentDeepLinkSubscription;
  PushNotificationsService? _pushNotificationsService;
  bool _isHandlingPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    ref.read(metaAppEventsServiceProvider).initialize();
    _pushNotificationsService = PushNotificationsService(
      supabaseService: ref.read(supabaseServiceProvider),
    );
    unawaited(
      _pushNotificationsService?.initialize(
            onOpenRoute: (route) {
              final router = ref.read(routerProvider);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                router.go(route);
              });
            },
          ) ??
          Future.value(),
    );
    if (Supabase.instance.client.auth.currentUser != null) {
      unawaited(
        _pushNotificationsService?.registerCurrentDevice() ?? Future.value(),
      );
    }
    unawaited(_handleInitialDeepLink());
    _paymentDeepLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingDeepLink,
    );
  }

  Future<void> _handleInitialDeepLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) {
      _handleIncomingDeepLink(uri);
    }
  }

  void _handleIncomingDeepLink(Uri uri) {
    final authRoute = routeForIncomingAuthRedirect(uri);
    if (authRoute != null) {
      _routeToPasswordRecovery();
      return;
    }

    final route = resolvePaymentDeepLinkRoute(uri);
    if (route == null) return;

    ref.invalidate(cartItemsProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(ordersStreamProvider);
    ref.invalidate(vendorSubscriptionProvider);
    ref.invalidate(vendorSubscriptionStreamProvider);

    final router = ref.read(routerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      router.go(route);
    });
  }

  void _routeToPasswordRecovery() {
    _isHandlingPasswordRecovery = true;
    final router = ref.read(routerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      router.go(passwordRecoveryRoute);
    });
  }

  @override
  void dispose() {
    _paymentDeepLinkSubscription?.cancel();
    unawaited(_pushNotificationsService?.dispose() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final router = ref.watch(routerProvider);

    ref.listen(authStateProvider, (_, next) {
      next.whenData((authState) async {
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _routeToPasswordRecovery();
          return;
        }

        if (authState.event == AuthChangeEvent.signedIn) {
          if (_isHandlingPasswordRecovery) {
            router.go(passwordRecoveryRoute);
            return;
          }
          final service = ref.read(supabaseServiceProvider);
          final profile = await service.syncCurrentUserProfile();
          await _pushNotificationsService?.registerCurrentDevice();
          final route =
              routeForAuthEvent(
                authState.event,
                role: profile?.role,
                requestedRole:
                    Supabase
                            .instance
                            .client
                            .auth
                            .currentUser
                            ?.userMetadata?['requested_role']
                        as String?,
              ) ??
              await service.getPostAuthRoute(profile: profile);
          router.go(route);
          return;
        }

        if (authState.event == AuthChangeEvent.signedOut) {
          if (_isHandlingPasswordRecovery) {
            _isHandlingPasswordRecovery = false;
            return;
          }
          final route = routeForAuthEvent(authState.event);
          if (route != null) {
            router.go(route);
          }
        }
      });
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
