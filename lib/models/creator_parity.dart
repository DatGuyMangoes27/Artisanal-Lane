/// A poll attached to a post. Results come from get_poll_results so
/// individual votes stay private.
class PostPoll {
  const PostPoll({
    required this.postId,
    required this.question,
    required this.options,
    this.closesAt,
  });

  final String postId;
  final String question;
  final List<String> options;
  final DateTime? closesAt;

  bool get isClosed => closesAt != null && !closesAt!.isAfter(DateTime.now());

  factory PostPoll.fromJson(Map<String, dynamic> json) => PostPoll(
    postId: json['post_id'] as String,
    question: json['question'] as String? ?? '',
    options: (json['options'] as List? ?? []).map((e) => e.toString()).toList(),
    closesAt: json['closes_at'] is String
        ? DateTime.tryParse(json['closes_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'post_id': postId,
    'question': question.trim(),
    'options': options.map((option) => option.trim()).toList(),
    'closes_at': closesAt?.toUtc().toIso8601String(),
  };
}

class PollResults {
  const PollResults({required this.votes, this.myVote});

  /// Vote count per option index.
  final List<int> votes;

  /// The signed-in user's option index, if they voted.
  final int? myVote;

  int get total => votes.fold(0, (sum, count) => sum + count);

  double share(int index) =>
      total == 0 || index >= votes.length ? 0 : votes[index] / total;

  factory PollResults.fromRows(List<dynamic> rows) {
    final sorted = rows.cast<Map<String, dynamic>>().toList()
      ..sort(
        (a, b) =>
            (a['option_index'] as int).compareTo(b['option_index'] as int),
      );
    return PollResults(
      votes: [for (final row in sorted) (row['votes'] as num).toInt()],
      myVote: sorted.isEmpty ? null : sorted.first['my_vote'] as int?,
    );
  }
}

/// A maker's own performance summary from get_shop_insights.
class ShopInsights {
  const ShopInsights({
    required this.days,
    required this.postViews,
    required this.productViews,
    required this.profileViews,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.newFollowers,
    required this.followers,
    required this.topPosts,
  });

  final int days;
  final int postViews;
  final int productViews;
  final int profileViews;
  final int likes;
  final int comments;
  final int saves;
  final int newFollowers;
  final int followers;

  /// Most viewed posts in the period: (postId, views), highest first.
  final List<({String postId, int views})> topPosts;

  factory ShopInsights.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ShopInsights(
      days: count('days'),
      postViews: count('post_views'),
      productViews: count('product_views'),
      profileViews: count('profile_views'),
      likes: count('likes'),
      comments: count('comments'),
      saves: count('saves'),
      newFollowers: count('new_followers'),
      followers: count('followers'),
      topPosts: [
        for (final row in (json['top_posts'] as List? ?? []).cast<Map>())
          (
            postId: row['post_id'] as String,
            views: (row['views'] as num).toInt(),
          ),
      ],
    );
  }
}

/// Reactions a viewer can send on a story (matches the database check).
const storyReactionEmojis = ['❤️', '🔥', '👏', '😍', '😮'];
