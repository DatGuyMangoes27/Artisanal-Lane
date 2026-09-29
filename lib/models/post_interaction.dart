class PostEngagement {
  const PostEngagement({
    required this.likes,
    required this.comments,
    required this.liked,
  });
  final int likes, comments;
  final bool liked;
  factory PostEngagement.fromJson(Map<String, dynamic> row) => PostEngagement(
    likes: (row['like_count'] as num).toInt(),
    comments: (row['comment_count'] as num).toInt(),
    liked: row['liked_by_me'] as bool,
  );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.userId,
    required this.body,
    required this.author,
    required this.createdAt,
    this.edited = false,
    this.pending = false,
    this.failed = false,
  });
  final String id, userId, body, author;
  final DateTime createdAt;
  final bool edited;

  /// Transient UI state for optimistic sends — not persisted, never comes
  /// from the server.
  final bool pending, failed;

  factory PostComment.fromJson(Map<String, dynamic> row) => PostComment(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    body: row['body'] as String,
    author: row['author_name'] as String? ?? 'Member',
    createdAt: DateTime.parse(row['created_at'] as String),
    edited: row['edited'] as bool? ?? false,
  );

  PostComment copyWith({
    String? body,
    bool? edited,
    bool? pending,
    bool? failed,
  }) => PostComment(
    id: id,
    userId: userId,
    body: body ?? this.body,
    author: author,
    createdAt: createdAt,
    edited: edited ?? this.edited,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
  );
}
