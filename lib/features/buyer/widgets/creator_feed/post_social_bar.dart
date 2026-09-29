import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/pricing/price_format.dart';
import '../../../../core/ui/compact_count.dart';
import '../../../../app/theme.dart';
import '../../../../models/shop_post.dart';
import '../../../../models/product.dart';
import '../../../../widgets/sign_in_prompt_sheet.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../vendor/providers/vendor_providers.dart';
import '../../providers/creator_parity_providers.dart';
import '../../providers/post_social_providers.dart';
import '../../screens/post_comments_screen.dart';
import '../../utils/shop_profile_actions.dart';

/// Optimistically flips the like state for [post] and rolls back on failure.
/// Shared by the social bar's heart button and the media double-tap gesture.
Future<void> togglePostLike(
  WidgetRef ref,
  BuildContext context, {
  required ShopPost post,
  required bool currentlyLiked,
  bool likeOnly = false,
}) async {
  final user = ref.read(currentUserIdProvider);
  if (user == null) {
    await showSignInPromptSheet(
      context,
      title: 'Support your favourite makers',
      message: 'Sign in to like this post.',
    );
    return;
  }
  if (likeOnly && currentlyLiked) return;
  final nextLiked = likeOnly ? true : !currentlyLiked;
  final controller = ref.read(postEngagementProvider(post.id).notifier);
  final previous = controller.applyLikeOptimistic(nextLiked);
  HapticFeedback.lightImpact();
  try {
    await ref.read(postSocialRepositoryProvider).setLiked(post.id, nextLiked);
  } catch (_) {
    if (previous != null) controller.restore(previous);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update your like. Try again.")),
      );
    }
  }
}

Future<void> sharePost(BuildContext context, ShopPost post) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await Share.share(
      buildPostShareText(
        shopId: post.shopId,
        shopName: post.shopName,
        caption: post.caption,
      ),
    );
  } catch (_) {
    messenger?.showSnackBar(
      const SnackBar(content: Text("Couldn't open sharing right now.")),
    );
  }
}

void showPostOptionsSheet(
  BuildContext context,
  WidgetRef ref, {
  required ShopPost post,
  required VoidCallback onOpenShop,
  required VoidCallback onReport,
  bool canReport = false,
}) {
  final saved = ref.read(isPostSavedProvider(post.id));
  final isOwner = ref.read(vendorShopProvider).value?.id == post.shopId;
  final makerName = post.shopName?.trim().isNotEmpty == true
      ? post.shopName!
      : 'this maker';
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(sheetContext);
              sharePost(context, post);
            },
          ),
          ListTile(
            key: const Key('post-options-save'),
            leading: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            title: Text(saved ? 'Unsave' : 'Save'),
            onTap: () {
              Navigator.pop(sheetContext);
              togglePostSaved(ref, context, post.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Visit shop'),
            onTap: () {
              Navigator.pop(sheetContext);
              onOpenShop();
            },
          ),
          if (!isOwner)
            ListTile(
              key: const Key('post-options-mute'),
              leading: const Icon(Icons.volume_off_outlined),
              title: Text('Mute $makerName'),
              onTap: () {
                Navigator.pop(sheetContext);
                setShopMuted(
                  ref,
                  context,
                  post.shopId,
                  muted: true,
                  shopName: post.shopName,
                );
              },
            ),
          if (canReport)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(sheetContext);
                onReport();
              },
            ),
          if (isOwner && post.hideLikeCount)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your like count is hidden from others.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class PostSocialBar extends ConsumerWidget {
  const PostSocialBar({super.key, required this.post});
  final ShopPost post;

  Future<void> _comments(BuildContext context) => showPostCommentsSheet(
    context,
    postId: post.id,
    shopId: post.shopId,
    commentsEnabled: post.commentsEnabled,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engagement = ref.watch(postEngagementProvider(post.id));
    final saved = ref.watch(isPostSavedProvider(post.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: 44,
            child: engagement.when(
              loading: () => _EngagementRow(
                onShare: () => sharePost(context, post),
                liked: false,
                likes: null,
                comments: null,
                onLike: null,
                onComments: null,
                saved: saved,
                onSave: () => togglePostSaved(ref, context, post.id),
              ),
              error: (_, _) => _EngagementRow(
                onShare: () => sharePost(context, post),
                liked: false,
                likes: null,
                comments: null,
                onLike: null,
                onComments: () => _comments(context),
                onRetry: () => ref.invalidate(postEngagementProvider(post.id)),
                saved: saved,
                onSave: () => togglePostSaved(ref, context, post.id),
              ),
              data: (state) => _EngagementRow(
                onShare: () => sharePost(context, post),
                liked: state.liked,
                likes: state.likes,
                comments: state.comments,
                onLike: () => togglePostLike(
                  ref,
                  context,
                  post: post,
                  currentlyLiked: state.liked,
                ),
                onComments: () => _comments(context),
                saved: saved,
                onSave: () => togglePostSaved(ref, context, post.id),
              ),
            ),
          ),
        ),
        if (post.productIds.isNotEmpty) _TaggedProducts(postId: post.id),
      ],
    );
  }
}

class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.liked,
    required this.likes,
    required this.comments,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.saved,
    required this.onSave,
    this.onRetry,
  });
  final bool liked;
  final int? likes;
  final int? comments;
  final VoidCallback? onLike;
  final VoidCallback? onComments;
  final VoidCallback onShare;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: liked ? 'Unlike post' : 'Like post',
        onPressed: onLike,
        icon: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? AppTheme.terracotta : AppTheme.textSecondary,
        ),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        // A hidden count (the maker's choice, sentinel from the repository)
        // never renders a number — and never the loading dash either.
        child: likes == hiddenLikeCountSentinel
            ? const SizedBox(key: ValueKey('hidden-likes'))
            : Text(
                likes == null ? '–' : formatCompactCount(likes!),
                key: ValueKey(likes),
                style: const TextStyle(fontSize: 13),
              ),
      ),
      const SizedBox(width: 12),
      IconButton(
        tooltip: 'Read comments',
        onPressed: onComments,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 22),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          comments == null ? '–' : formatCompactCount(comments!),
          key: ValueKey(comments),
          style: const TextStyle(fontSize: 13),
        ),
      ),
      const SizedBox(width: 12),
      IconButton(
        tooltip: 'Share post',
        onPressed: onShare,
        icon: const Icon(Icons.share_outlined, size: 21),
      ),
      if (onRetry != null) ...[
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Retry',
          iconSize: 18,
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      const Spacer(),
      IconButton(
        tooltip: saved ? 'Unsave post' : 'Save post',
        onPressed: onSave,
        icon: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          color: saved ? AppTheme.terracotta : AppTheme.textSecondary,
        ),
      ),
    ],
  );
}

/// A compact horizontal row of tagged-product chips ("Shop this post"),
/// replacing the old full-width list under every post.
class _TaggedProducts extends ConsumerWidget {
  const _TaggedProducts({required this.postId});
  final String postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(postProductsProvider(postId))
      .when(
        // A quiet, degraded placeholder rather than a full loading/error row.
        loading: () => const SizedBox(height: 4),
        error: (_, _) => const SizedBox.shrink(),
        data: (products) => products.isEmpty
            ? const SizedBox.shrink()
            : SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) =>
                      _ProductChip(product: products[index]),
                ),
              ),
      );
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/home/product/${product.id}'),
    borderRadius: BorderRadius.circular(30),
    child: Container(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 200),
      padding: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.sand),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(30),
            ),
            child: product.images.isEmpty
                ? Container(width: 44, height: 44, color: AppTheme.bone)
                : CachedNetworkImage(
                    imageUrl: product.images.first,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        Container(width: 44, height: 44, color: AppTheme.bone),
                  ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatBrowsePrice(product.price),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF435951),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
