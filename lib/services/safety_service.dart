import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/providers/auth_providers.dart';

/// Data calls for user-generated-content safety (community guidelines).
/// Kept separate from SupabaseService so the safety feature owns its RPCs.
class SafetyService {
  SafetyService(this._client);
  final SupabaseClient _client;

  /// When the signed-in member accepted the community guidelines, or null.
  Future<DateTime?> fetchCommunityGuidelinesAcceptedAt() async {
    final value = await _client.rpc('get_my_community_guidelines_acceptance');
    return _parse(value);
  }

  /// Records acceptance for the signed-in member only (server-side RPC; the
  /// column is not writable directly). Returns the stored acceptance time.
  Future<DateTime> acceptCommunityGuidelines() async {
    final value = await _client.rpc('accept_community_guidelines');
    return _parse(value) ?? DateTime.now();
  }

  static DateTime? _parse(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is List && value.isNotEmpty) return _parse(value.first);
    if (value is Map && value.isNotEmpty) return _parse(value.values.first);
    return null;
  }
}

final safetyServiceProvider = Provider<SafetyService>(
  (ref) => SafetyService(ref.read(supabaseClientProvider)),
);
