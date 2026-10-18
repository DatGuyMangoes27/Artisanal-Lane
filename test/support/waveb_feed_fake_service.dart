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
    // Behave like get_poll_results after the write: one vote per person,
    // changing a vote moves it.
    final current = pollResultsByPostId[postId];
    if (current == null) return;
    final votes = List<int>.from(current.votes);
    if (current.myVote != null && current.myVote! < votes.length) {
      votes[current.myVote!]--;
    }
    if (optionIndex < votes.length) votes[optionIndex]++;
    pollResultsByPostId[postId] = PollResults(
      votes: votes,
      myVote: optionIndex,
    );
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
