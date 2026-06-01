import 'package:supabase_flutter/supabase_flutter.dart';

const String passwordRecoveryRoute = '/reset-password';
const String authCallbackScheme = 'artisanlane';
const String authCallbackHost = 'login-callback';

bool isPasswordRecoveryRoute(String path) {
  return path == passwordRecoveryRoute;
}

String? routeForIncomingAuthRedirect(Uri uri) {
  if (uri.scheme != authCallbackScheme || uri.host != authCallbackHost) {
    return null;
  }

  final params = {
    ...uri.queryParameters,
    ...Uri.splitQueryString(uri.fragment),
  };
  return params['type'] == 'recovery' ? passwordRecoveryRoute : null;
}

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
