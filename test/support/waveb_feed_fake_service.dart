import 'package:artisanal_lane/models/creator_parity.dart';
import 'package:artisanal_lane/services/supabase_service.dart';

/// In-memory stand-in for the parts of SupabaseService the feed touches.
/// Implements (not extends) so no real client is ever needed.
class FakeSupabaseService implements SupabaseService {
  final pollByPostId = <String, PostPoll>{};
  final pollResultsByPostId = <String, PollResults>{};
  final voteCalls = <(String, int)>[];
  bool voteFails = false;
  final saved = <String>{};
  final muted = <String>{};
  final viewCalls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PostPoll?> getPostPoll(String postId) async => pollByPostId[postId];

  @override
  Future<PollResults> getPollResults(String postId) async =>
      pollResultsByPostId[postId] ?? const PollResults(votes: []);

  @override
  Future<void> votePoll(String postId, int optionIndex) async {
    if (voteFails) throw StateError('network');
    voteCalls.add((postId, optionIndex));
  }

  @override
  Future<Set<String>> getSavedPostIds() async => {...saved};

  @override
  Future<void> setPostSaved(String postId, bool value) async {
    value ? saved.add(postId) : saved.remove(postId);
  }

  @override
  Future<Set<String>> getMutedShopIds() async => {...muted};

  @override
  Future<void> setShopMuted(String shopId, bool value) async {
    value ? muted.add(shopId) : muted.remove(shopId);
  }
}
