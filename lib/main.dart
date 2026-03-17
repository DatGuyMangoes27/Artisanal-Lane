import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: ArtisanalLaneApp()));
}

class ArtisanalLaneApp extends ConsumerWidget {
  const ArtisanalLaneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
