import '../../../models/shop_post.dart';

/// Keyset ("seek") cursor for the creator feed: the last post the server
/// returned, ordered by `published_at desc, id desc`.
///
/// Offset paging (`range(offset, ...)`) breaks as soon as the underlying
/// list changes between pages: a newly published post shifts every later
/// page down by one (the same post comes back twice), and a deleted or
/// unpublished post, or one dropped locally (unfollowing in Following),
/// shifts it up (a post is skipped or refetched). A cursor always asks for
/// "strictly older than the last post I already have", so pages never
/// overlap however the feed changes underneath.
class FeedCursor {
  const FeedCursor({required this.publishedAt, required this.id});

  final DateTime publishedAt;
  final String id;

  /// The cursor after [page], or null when the page is empty.
  static FeedCursor? after(List<ShopPost> page) => page.isEmpty
      ? null
      : FeedCursor(publishedAt: page.last.publishedAt, id: page.last.id);

  /// PostgREST `or` filter selecting rows that sort strictly after this
  /// cursor in `published_at desc, id desc` order. Values are quoted so the
  /// timestamp's `:` and `.` never confuse the logic-tree parser.
  String get olderThanFilter {
    final at = publishedAt.toUtc().toIso8601String();
    return 'published_at.lt."$at",'
        'and(published_at.eq."$at",id.lt."$id")';
  }
}

/// Appends [next] to [loaded], skipping any post id already present (or
/// repeated inside [next] itself). Returns the posts actually added.
List<ShopPost> appendUniquePosts(List<ShopPost> loaded, List<ShopPost> next) {
  final seen = {for (final post in loaded) post.id};
  final added = <ShopPost>[];
  for (final post in next) {
    if (seen.add(post.id)) added.add(post);
  }
  loaded.addAll(added);
  return added;
}

/// Order-preserving de-duplication by post id (first occurrence wins).
List<ShopPost> dedupePostsById(Iterable<ShopPost> posts) {
  final seen = <String>{};
  return [
    for (final post in posts)
      if (seen.add(post.id)) post,
  ];
}
