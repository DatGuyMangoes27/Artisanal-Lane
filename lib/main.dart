import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/buyer/providers/buyer_providers.dart';
import 'features/buyer/utils/payment_deep_links.dart';

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
        if (authState.event == AuthChangeEvent.signedIn) {
          final service = ref.read(supabaseServiceProvider);
          final profile = await service.syncCurrentUserProfile();
          final route = await service.getPostAuthRoute(profile: profile);
          router.go(route);
        }

        if (authState.event == AuthChangeEvent.signedOut) {
          router.go('/welcome');
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
