import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/shop_post.dart';
import '../../../widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../providers/creator_parity_providers.dart';
import '../widgets/creator_feed/creator_feed_post_card.dart';
import '../../vendor/services/creator_post_media.dart';

/// Full [ShopPost] rows behind the signed-in buyer's saved posts, newest
/// save first. Distinct from [savedPostIdsProvider] (just the ids).
final savedPostsProvider = FutureProvider<List<ShopPost>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.read(supabaseServiceProvider).getSavedPosts();
});

/// A 3-column grid of everything the buyer has saved, opening a post
/// full-screen on tap. Mirrors the demo's saved-posts concept (see
/// docs/design-language.md) with a friendly empty state.
class SavedPostsScreen extends ConsumerWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedPostsProvider);
    final savedIds = ref.watch(savedPostIdsProvider).value ?? const <String>{};

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        title: Text(
          'Saved posts',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: () async => ref.invalidate(savedPostsProvider),
          child: savedAsync.when(
            data: (posts) {
              // Posts unsaved from this screen (or elsewhere) disappear
              // instantly without waiting on a refetch.
              final visible = posts
                  .where((post) => savedIds.contains(post.id))
                  .toList(growable: false);
              if (visible.isEmpty) {
                return const _SavedPostsEmptyState();
              }
              return GridView.builder(
                padding: const EdgeInsets.all(3),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  childAspectRatio: 1,
                ),
                itemCount: visible.length,
                itemBuilder: (context, index) => _SavedPostTile(
                  post: visible[index],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _SavedPostViewerScreen(post: visible[index]),
                    ),
                  ),
                ),
              );
            },
            loading: () => const _SavedPostsGridSkeleton(),
            error: (error, _) => ErrorRetryView(
              error: error,
              title: "Couldn't load your saved posts",
              onRetry: () => ref.invalidate(savedPostsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedPostTile extends ConsumerWidget {
  final ShopPost post;
  final VoidCallback onTap;

  const _SavedPostTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo =
        post.mediaUrls.isNotEmpty &&
        isCreatorPostMediaMarker(post.primaryImage);
    final coverImage = post.mediaUrls.firstWhere(
      (url) => !isCreatorPostMediaMarker(url),
      orElse: () => '',
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppTheme.bone,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverImage.isNotEmpty)
              CachedNetworkImage(
                imageUrl: coverImage,
                fit: BoxFit.cover,
                placeholder: (_, __) => Skeleton(child: SkeletonBox(radius: 0)),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppTheme.textHint,
                ),
              )
            else if (!isVideo)
              const Icon(
                Icons.image_not_supported_outlined,
                color: AppTheme.textHint,
              ),
            if (isVideo)
              Container(
                color: Colors.black.withValues(
                  alpha: coverImage.isEmpty ? 0.85 : 0.15,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            Positioned(
              right: 4,
              top: 4,
              child: Semantics(
                label: 'Unsave this post',
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => togglePostSaved(ref, context, post.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPostsGridSkeleton extends StatelessWidget {
  const _SavedPostsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: GridView.builder(
        padding: const EdgeInsets.all(3),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          childAspectRatio: 1,
        ),
        itemCount: 9,
        itemBuilder: (context, index) => SkeletonBox(radius: 0),
      ),
    );
  }
}

class _SavedPostsEmptyState extends StatelessWidget {
  const _SavedPostsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_border_rounded,
              size: 40,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: 14),
            Text(
              'Nothing saved yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Save posts to find them here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen viewer for a single saved post, reusing [CreatorFeedPostCard]
/// so it looks the same here as in the creator feed and maker profile.
class _SavedPostViewerScreen extends ConsumerWidget {
  final ShopPost post;

  const _SavedPostViewerScreen({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopId = post.shopId;
    final isFollowing =
        ref.watch(isFollowingProvider(shopId)).asData?.value ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          post.shopName ?? 'Post',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: CreatorFeedPostCard(
            post: post,
            isFollowing: isFollowing,
            onOpenShop: () => Navigator.of(context).pop(),
            onFollowToggle: () async {
              final service = ref.read(supabaseServiceProvider);
              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;
              if (isFollowing) {
                await service.unfollowShop(userId, shopId);
              } else {
                await service.followShop(userId, shopId);
              }
              ref.invalidate(isFollowingProvider(shopId));
            },
          ),
        ),
      ),
    );
  }
}
