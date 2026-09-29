import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'post_publication.dart';

/// Saves the immutable, uploaded submission before its first database write.
/// Recovery reuses its ID; it never automatically publishes on app launch.
class PendingPostStore {
  PendingPostStore(this.preferences);
  final SharedPreferences preferences;
  String _key(String user) => 'pending_post_submission_v1:$user';

  PostPublication? read(String user) {
    final raw = preferences.getString(_key(user));
    if (raw == null) return null;
    return PostPublication.fromStored(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(String user, PostPublication submission) async {
    final pending = read(user);
    if (pending != null && pending.id != submission.id) {
      throw StateError(
        'Confirm your previous pending post before creating another.',
      );
    }
    if (!await preferences.setString(
      _key(user),
      jsonEncode(submission.stored),
    )) {
      throw StateError('Could not save a safe retry. Please try again.');
    }
  }

  Future<void> clear(String user, String id) async {
    // Never clear a newer submission written by another editor.
    if (read(user)?.id == id && !await preferences.remove(_key(user))) {
      throw StateError(
        'Post saved. Reopen the editor to confirm its saved state.',
      );
    }
  }
}
