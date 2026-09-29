import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/shop_story.dart';
import '../../auth/providers/auth_providers.dart';
import '../utils/story_publication.dart';

final storyRepositoryProvider = Provider(
  (ref) => StoryRepository(ref.watch(supabaseClientProvider)),
);
final storiesProvider = FutureProvider<List<ShopStory>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(storyRepositoryProvider).load();
});
final seenStoriesProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserIdProvider);
  if (user == null) return {};
  return ref.watch(storyRepositoryProvider).seen(user);
});

/// Optimistic local overlay so the rail's seen ring updates the instant a
/// story is viewed, without waiting for [seenStoriesProvider] to refetch.
class LocallySeenStories extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};
  void add(String storyId) => state = {...state, storyId};
}

final locallySeenStoriesProvider =
    NotifierProvider<LocallySeenStories, Set<String>>(LocallySeenStories.new);

/// The signed-in viewer's own reaction on a story, if any.
class MyStoryReactionController extends AsyncNotifier<String?> {
  MyStoryReactionController(this.storyId);
  final String storyId;

  @override
  Future<String?> build() async {
    if (ref.watch(currentUserIdProvider) == null) return null;
    return ref.watch(supabaseServiceProvider).getMyStoryReaction(storyId);
  }

  /// Sets, changes or (with null) removes the reaction immediately, rolling
  /// back if the save fails. Returns false when it failed.
  Future<bool> setReaction(String? emoji) async {
    final previous = state.value;
    if (previous == emoji) return true;
    state = AsyncData(emoji);
    try {
      await ref.read(supabaseServiceProvider).setStoryReaction(storyId, emoji);
      return true;
    } catch (_) {
      state = AsyncData(previous);
      return false;
    }
  }
}

final myStoryReactionProvider =
    AsyncNotifierProvider.family<MyStoryReactionController, String?, String>(
      MyStoryReactionController.new,
    );

/// For the story's maker: reactions with reactor display names. Loaded fresh
/// each time the reactions sheet opens.
final storyReactionsProvider = FutureProvider.autoDispose
    .family<List<({String emoji, String name})>, String>(
      (ref, storyId) =>
          ref.watch(supabaseServiceProvider).getStoryReactions(storyId),
    );

class StoryRepository {
  StoryRepository(this.client);
  final SupabaseClient client;
  static const bucket = 'creator-stories';
  Future<List<ShopStory>> load() async {
    final rows = await client
        .from('shop_stories')
        .select('*, shops(name, logo_url)')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map(ShopStory.fromJson).toList();
  }

  Future<Set<String>> seen(String user) async {
    final rows = await client
        .from('shop_story_views')
        .select('story_id, shop_stories!inner(expires_at)')
        .eq('user_id', user)
        .gt(
          'shop_stories.expires_at',
          DateTime.now().toUtc().toIso8601String(),
        );
    return rows.map((r) => r['story_id'] as String).toSet();
  }

  Future<void> markSeen(String id) async {
    final user = client.auth.currentUser?.id;
    if (user == null) return;
    await client
        .from('shop_story_views')
        .upsert(
          {'user_id': user, 'story_id': id},
          onConflict: 'user_id,story_id',
          ignoreDuplicates: true,
        );
  }

  Future<Uint8List> media(ShopStory story) async {
    if (!story.isLiveAt(DateTime.now())) {
      throw StateError('This story has expired.');
    }
    return client.storage.from(bucket).download(story.mediaPath);
  }

  Future<void> publish({
    required String requestId,
    required String shopId,
    required XFile file,
    required bool video,
    required String caption,
  }) async {
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('Please sign in again.');
    if (await file.length() > 50 * 1024 * 1024) {
      throw StateError('Choose a file smaller than 50 MB.');
    }
    final extension = file.path.split('.').last.toLowerCase();
    final types = video
        ? {'mp4': 'video/mp4', 'mov': 'video/quicktime'}
        : {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'webp': 'image/webp',
          };
    final contentType = types[extension];
    if (contentType == null) {
      throw StateError('Choose a JPG, PNG, WebP, MP4 or MOV file.');
    }
    final path = '$user/$requestId.$extension';
    final publication = StoryPublication(
      id: requestId,
      shopId: shopId,
      mediaPath: path,
      mediaType: video ? 'video' : 'image',
      caption: caption.trim(),
    );
    void checkAccount() {
      if (client.auth.currentUser?.id != user) {
        throw StateError('Your account changed. Please sign in again.');
      }
    }

    await publication.ensurePublished(
      find: () async {
        checkAccount();
        final row = await client
            .from('shop_stories')
            .select('id,shop_id,media_path,media_type,caption')
            .eq('id', requestId)
            .maybeSingle();
        checkAccount();
        return row;
      },
      upload: () async {
        checkAccount();
        try {
          await client.storage
              .from(bucket)
              .uploadBinary(
                path,
                await file.readAsBytes(),
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: false,
                ),
              );
        } on StorageException catch (error) {
          // A prior upload may have succeeded before its response was lost.
          // Never overwrite media. Only the exact same UUID/path can be reused.
          if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
        }
        checkAccount();
      },
      insert: (row) async {
        checkAccount();
        await client
            .from('shop_stories')
            .upsert(row, onConflict: 'id', ignoreDuplicates: true);
      },
    );
  }

  Future<void> delete(ShopStory story) async {
    await client
        .from('shop_stories')
        .delete()
        .eq('id', story.id)
        .select('id')
        .single();
    try {
      await client.storage.from(bucket).remove([story.mediaPath]);
    } catch (_) {
      /* Publication is already removed; retention handles the file. */
    }
  }
}
