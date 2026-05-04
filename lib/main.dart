import 'dart:async';

import 'package:app_links/app_links.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    ref.read(metaAppEventsServiceProvider).initialize();
    _paymentDeepLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingDeepLink,
    );
  }

  void _handleIncomingDeepLink(Uri uri) {
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

  @override
  void dispose() {
    _paymentDeepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final router = ref.watch(routerProvider);

    ref.listen(authStateProvider, (_, next) {
      next.whenData((authState) async {
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          router.go(passwordRecoveryRoute);
          return;
        }

        if (authState.event == AuthChangeEvent.signedIn) {
          final service = ref.read(supabaseServiceProvider);
          final profile = await service.syncCurrentUserProfile();
          final route =
              routeForAuthEvent(
                authState.event,
                role: profile?.role,
                requestedRole:
                    Supabase.instance.client.auth.currentUser?.userMetadata?['requested_role']
                        as String?,
              ) ??
              await service.getPostAuthRoute(profile: profile);
          router.go(route);
          return;
        }

        if (authState.event == AuthChangeEvent.signedOut) {
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
