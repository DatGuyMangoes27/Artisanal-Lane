import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which single feed post's video should be actively playing.
/// Only one in-feed video plays at a time; scrolling a new one into view
/// (or none at all) replaces the active id.
class ActiveFeedVideoController extends Notifier<String?> {
  @override
  String? build() => null;

  void setActive(String? postId) {
    if (state != postId) state = postId;
  }

  void clearIfActive(String postId) {
    if (state == postId) state = null;
  }
}

final activeFeedVideoPostIdProvider =
    NotifierProvider<ActiveFeedVideoController, String?>(
      ActiveFeedVideoController.new,
    );

/// Per-post mute state for in-feed video. Absent from the set means muted,
/// matching how short-form video autoplay normally starts.
class FeedVideoMuteController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool isUnmuted(String postId) => state.contains(postId);

  void toggle(String postId) {
    final next = {...state};
    if (!next.remove(postId)) next.add(postId);
    state = next;
  }
}

final feedVideoUnmutedPostIdsProvider =
    NotifierProvider<FeedVideoMuteController, Set<String>>(
      FeedVideoMuteController.new,
    );

/// Fraction (0.0–1.0) of an item's height that sits inside the viewport.
/// Pure geometry so it is testable without mounting real RenderBoxes.
double visibleFraction({
  required double itemTop,
  required double itemHeight,
  required double viewportHeight,
}) {
  if (itemHeight <= 0 || viewportHeight <= 0) return 0;
  final itemBottom = itemTop + itemHeight;
  final visibleTop = itemTop.clamp(0.0, viewportHeight);
  final visibleBottom = itemBottom.clamp(0.0, viewportHeight);
  final visible = (visibleBottom - visibleTop).clamp(0.0, itemHeight);
  return visible / itemHeight;
}

/// A video post must be at least this visible before it autoplays.
const feedVideoVisibilityThreshold = 0.6;
