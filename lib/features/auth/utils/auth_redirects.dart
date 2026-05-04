import 'package:supabase_flutter/supabase_flutter.dart';

const String passwordRecoveryRoute = '/reset-password';

String? routeForAuthEvent(
  AuthChangeEvent event, {
  String? role,
  String? requestedRole,
}) {
  switch (event) {
    case AuthChangeEvent.passwordRecovery:
      return passwordRecoveryRoute;
    case AuthChangeEvent.signedOut:
      return '/welcome';
    case AuthChangeEvent.signedIn:
      if (role == 'vendor') {
        return '/vendor';
      }
      if (requestedRole == 'vendor') {
        return '/vendor/onboarding';
      }
      return '/home';
    default:
      return null;
  }
}
