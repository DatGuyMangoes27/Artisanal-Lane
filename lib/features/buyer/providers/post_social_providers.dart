import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/post_interaction.dart';
import '../../../models/product.dart';
import '../../auth/providers/auth_providers.dart';

/// The model's `likes` field has no way to say "hidden", so the repository
/// folds a maker-hidden like count (server returns `like_count: null` for
/// non-owners) into this sentinel. UI code must treat it as "show nothing",
/// never as a literal -1, and must never do arithmetic on it.
const hiddenLikeCountSentinel = -1;

final postSocialRepositoryProvider = Provider(
  (ref) => PostSocialRepository(ref.watch(supabaseClientProvider)),
);

/// Cached per-post engagement (likes/comments/liked-by-me). Deliberately not
/// autoDispose: scrolling a post off screen and back must not reload or
/// jump the counts, so the last known state stays around for the session.
class PostEngagementController extends AsyncNotifier<PostEngagement> {
  PostEngagementController(this.postId);
  final String postId;
  String? _forUser;

  @override
  Future<PostEngagement> build() async {
    final user = ref.watch(currentUserIdProvider);
    _forUser = user;
    return ref.watch(postSocialRepositoryProvider).engagement(postId);
  }

  /// Flips the like immediately. Returns the previous state so callers can
  /// roll back on failure.
  PostEngagement? applyLikeOptimistic(bool liked) {
    final current = state.value;
    if (current == null) return null;
    final hidden = current.likes == hiddenLikeCountSentinel;
    state = AsyncData(
      PostEngagement(
        likes: hidden ? current.likes : current.likes + (liked ? 1 : -1),
        comments: current.comments,
        liked: liked,
      ),
    );
    return current;
  }

  void restore(PostEngagement previous) {
    state = AsyncData(previous);
  }

  void bumpComments(int delta) {
    final current = state.value;
    if (current == null) return;
    final next = current.comments + delta;
    state = AsyncData(
      PostEngagement(
        likes: current.likes,
        comments: next < 0 ? 0 : next,
        liked: current.liked,
      ),
    );
  }

  /// True once the cache belongs to the signed-in user currently reading it
  /// (a fresh build() is triggered by auth_providers when the user changes).
  bool get matchesCurrentUser => _forUser == ref.read(currentUserIdProvider);
}

final postEngagementProvider =
    AsyncNotifierProvider.family<
      PostEngagementController,
      PostEngagement,
      String
    >(PostEngagementController.new);

final postProductsProvider = FutureProvider.autoDispose
    .family<List<Product>, String>((ref, postId) async {
      ref.watch(currentUserIdProvider);
      return ref.watch(postSocialRepositoryProvider).products(postId);
    });

class PostSocialRepository {
  PostSocialRepository(this.client);
  final SupabaseClient client;
  String get _user =>
      client.auth.currentUser?.id ?? (throw StateError('Sign in to continue.'));
  Future<PostEngagement> engagement(String postId) async {
    final rows = await client.rpc(
      'get_post_engagement',
      params: {
        'post_ids': [postId],
      },
    );
    if ((rows as List).isEmpty) throw StateError('Post unavailable');
    final row = Map<String, dynamic>.from(rows.first);
    // The maker hid likes and this viewer isn't the owner: fold the null
    // count into a sentinel the UI knows to hide.
    if (row['like_count'] == null) row['like_count'] = hiddenLikeCountSentinel;
    return PostEngagement.fromJson(row);
  }

  Future<void> setLiked(String postId, bool liked) async {
    final user = _user;
    if (liked) {
      await client
          .from('shop_post_likes')
          .upsert(
            {'post_id': postId, 'user_id': user},
            onConflict: 'post_id,user_id',
            ignoreDuplicates: true,
          );
    } else {
      await client
          .from('shop_post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user);
    }
  }

  Future<List<PostComment>> comments(
    String postId, {
    PostComment? before,
  }) async {
    var query = client
        .from('shop_post_comments')
        .select()
        .eq('post_id', postId);
    if (before != null) {
      final at = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$at,and(created_at.eq.$at,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(30);
    return rows.map(PostComment.fromJson).toList();
  }

  Future<void> addComment(String postId, String body, String requestId) async {
    if (body.trim().isEmpty || body.trim().runes.length > 1000) {
      throw ArgumentError('Write a comment of 1–1,000 characters.');
    }
    await client
        .from('shop_post_comments')
        .upsert(
          {
            'id': requestId,
            'post_id': postId,
            'user_id': _user,
            'body': body.trim(),
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }

  Future<void> editComment(String id, String body) async {
    await client
        .from('shop_post_comments')
        .update({'body': body.trim()})
        .eq('id', id)
        .eq('user_id', _user)
        .select('id')
        .single();
  }

  Future<void> deleteComment(String id) async {
    await client
        .from('shop_post_comments')
        .delete()
        .eq('id', id)
        .select('id')
        .single();
  }

  Future<List<Product>> products(String postId) async {
    final post = await client
        .from('shop_posts')
        .select('shop_id,product_ids')
        .eq('id', postId)
        .single();
    final ids = (post['product_ids'] as List).cast<String>();
    if (ids.isEmpty) return [];
    final rows = await client
        .from('products')
        .select('*, shops(name, logo_url)')
        .inFilter('id', ids)
        .eq('shop_id', post['shop_id'])
        .eq('is_published', true);
    final products = rows.map(Product.fromJson).toList();
    products.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return products;
  }
}
