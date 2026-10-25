import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/models.dart';
import '../../../services/supabase_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(ref.read(supabaseClientProvider));
});

/// Streams auth state changes from Supabase.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// The currently authenticated user, or null.
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

/// Convenience provider for the current user's ID. Returns null if not logged in.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser?.id;
});

/// The current user's profile from the database. Only fetched when authenticated.
///
/// It also re-reads on every auth event (sign-in, token refresh), not only
/// when the user id changes. Otherwise a first read that failed while a
/// restored session was still refreshing its token stayed cached as `null`,
/// and an artisan looked like a buyer (no Selling switch, "Start selling"
/// shown) until something else happened to refresh the profile.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  try {
    return await service.getProfile(userId);
  } catch (_) {
    return null;
  }
});
