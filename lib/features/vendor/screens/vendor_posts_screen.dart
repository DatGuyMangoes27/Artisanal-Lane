import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/vendor_providers.dart';

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
        title: Text('Shop Posts', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/vendor/profile/posts/new'),
        backgroundColor: AppTheme.terracotta,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.feed_outlined, size: 56, color: AppTheme.textHint),
                    const SizedBox(height: 16),
                    Text('No Posts Yet', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Share updates, new products, and behind-the-scenes with your followers', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.terracotta,
            onRefresh: () async => ref.invalidate(vendorPostsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _buildPostTile(context, ref, posts[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPostTile(BuildContext context, WidgetRef ref, ShopPost post) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.mediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: post.primaryImage,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppTheme.bone),
                  errorWidget: (_, __, ___) => Container(color: AppTheme.bone),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.caption,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textPrimary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      post.timeAgo,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textHint),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/vendor/profile/posts/${post.id}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.bone,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Edit', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.terracotta)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDelete(context, ref, post.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Delete', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Post', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
        content: Text('This cannot be undone.', style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(supabaseServiceProvider);
              await service.deleteShopPost(postId);
              ref.invalidate(vendorPostsProvider);
            },
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
