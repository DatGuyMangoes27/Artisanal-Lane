import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/providers/auth_providers.dart';

/// Anonymous, random per-install id so guest views count once per day in maker
/// insights. It identifies nothing about the person and never leaves the
/// view-counting call. Signed-in views are keyed by account on the server.
class ContentViewSession {
  static const _key = 'content_view_session_v1';
  static String? _cached;

  static Future<String> id() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString(_key);
    if (value == null) {
      final random = Random.secure();
      value = List.generate(
        24,
        (_) => random.nextInt(36).toRadixString(36),
      ).join();
      await prefs.setString(_key, value);
    }
    return _cached = value;
  }
}

/// Records one view of a post, product or shop for the maker's insights.
/// Safe to call often: the server keeps one per viewer per item per day and
/// ignores makers viewing their own shop.
Future<void> recordContentView(WidgetRef ref, String kind, String id) async {
  final signedIn = ref.read(currentUserIdProvider) != null;
  final session = signedIn ? null : await ContentViewSession.id();
  await ref
      .read(supabaseServiceProvider)
      .recordContentView(kind, id, guestSession: session);
}
