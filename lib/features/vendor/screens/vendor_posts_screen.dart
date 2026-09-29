import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../widgets/gradient_fab.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';
import '../services/creator_post_media.dart';
import '../widgets/composer/composer_format_picker.dart';
import '../widgets/workspace/workspace_stat_tile.dart';

class VendorPostsScreen extends ConsumerWidget {
  const VendorPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(vendorPostsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Shop Posts',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        onTap: () => context.push('/vendor/profile/posts/new'),
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return WorkspaceEmptyState(
              icon: Icons.feed_outlined,
              title: 'No posts yet',
              message:
                  'Share updates, new products, and behind-the-scenes with your followers.',
              actionLabel: 'New post',
              onAction: () => context.push('/vendor/profile/posts/new'),
            );
          }
          return RefreshIndicator(
            color: AppTheme.terracotta,
            onRefresh: () async => ref.invalidate(vendorPostsProvider),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 0.8,
              ),
              itemCount: posts.length,
              itemBuilder: (_, i) => _buildPostTile(context, ref, posts[i]),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.terracotta,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPostTile(BuildContext context, WidgetRef ref, ShopPost post) {
    return GestureDetector(
      onTap: () => _showPostActionsSheet(context, ref, post),
      child: Container(
        color: AppTheme.bone,
        child: Stack(
          fit: StackFit.expand,
          children: [
            post.mediaUrls.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: Center(
                      child: Text(
                        post.caption,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                : isCreatorPostMediaMarker(post.primaryImage)
                ? const _PrivateVideoTile()
                : CachedNetworkImage(
                    imageUrl: post.primaryImage,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.bone),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppTheme.bone),
                  ),
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  composerFormatIcon(post.format),
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
            if (post.isScheduled)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.ochre,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Scheduled',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPostActionsSheet(
    BuildContext context,
    WidgetRef ref,
    ShopPost post,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 44,
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.terracotta,
                ),
                title: Text('Edit post', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/vendor/profile/posts/${post.id}');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 44,
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.error,
                ),
                title: Text(
                  'Delete post',
                  style: GoogleFonts.poppins(color: AppTheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(context, ref, post.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Post',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This cannot be undone.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(supabaseServiceProvider);
              await service.deleteShopPost(postId);
              ref.invalidate(vendorPostsProvider);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateVideoTile extends StatelessWidget {
  const _PrivateVideoTile();
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.indigo,
    alignment: Alignment.center,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48),
        SizedBox(height: 8),
        Text('Private video', style: TextStyle(color: Colors.white)),
      ],
    ),
  );
}
