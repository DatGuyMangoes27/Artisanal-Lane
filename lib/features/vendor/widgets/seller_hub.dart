import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../providers/vendor_providers.dart';
import '../screens/shop_insights_screen.dart' show shopInsightsProvider;

/// Seller-facing name and subtitle of the photo tools (formerly "AI studio").
/// The tools brighten and tidy product photos; they do not stage products in
/// new scenes, so the label says exactly that.
const kPhotoEnhancerTitle = 'Photo enhancer';
const kPhotoEnhancerSubtitle = 'Brighten and clean up product photos';

/// Where a maker's stories appear for shoppers, shown in the story composer
/// and on the Add story tile so sellers know what happens after they post.
const kStoryPlacementNote =
    'Stories show in the circles at the top of the Feed for 24 hours.';

/// Maker card for the selling hub: logo, shop name, handle and counts.
/// Shared by the You tab (Selling) so both seller entry points match.
class SellerShopCard extends ConsumerWidget {
  const SellerShopCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(vendorShopProvider);
    final postsCount = ref.watch(vendorPostsProvider).asData?.value.length;
    final productsCount = ref
        .watch(vendorProductsProvider)
        .asData
        ?.value
        .length;

    return shopAsync.when(
      data: (shop) {
        if (shop == null) return const SizedBox.shrink();
        return Container(
          key: const ValueKey('seller-shop-card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.bone,
                backgroundImage: shop.logoUrl != null
                    ? CachedNetworkImageProvider(shop.logoUrl!)
                    : null,
                child: shop.logoUrl == null
                    ? Text(
                        shop.name.isNotEmpty ? shop.name[0] : 'S',
                        style: GoogleFonts.playfairDisplay(
                          color: AppTheme.terracotta,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (shop.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppTheme.baobab,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      shop.handle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _stat('${productsCount ?? 0}', 'products'),
                        const SizedBox(width: 16),
                        _stat('${postsCount ?? 0}', 'posts'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _stat(String value, String label) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }
}

/// The seller quick actions: Create post, Add story, Add product, Photo
/// enhancer and Insights. Used on the You tab (Selling) and on the artisan
/// Dashboard so the same tools are reachable from either side of the app.
///
/// [onAddProduct] and [onPhotoEnhancer] let the Dashboard keep its
/// subscription / payout gate in front of the product form.
class SellerToolTiles extends ConsumerWidget {
  const SellerToolTiles({super.key, this.onAddProduct, this.onPhotoEnhancer});

  final VoidCallback? onAddProduct;
  final VoidCallback? onPhotoEnhancer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(vendorShopProvider).asData?.value;
    final insights = shop == null
        ? null
        : ref.watch(shopInsightsProvider(30)).asData?.value;

    return Column(
      key: const ValueKey('seller-tool-tiles'),
      children: [
        _pair(
          SellerToolTile(
            icon: Icons.add_circle_outline,
            title: 'Create post',
            subtitle: 'Photos and more',
            onTap: () => context.push('/create/post'),
          ),
          SellerToolTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Add story',
            subtitle: 'Top of the Feed for 24 hours',
            onTap: shop == null
                ? null
                : () => context.push('/create/story', extra: shop),
          ),
        ),
        const SizedBox(height: 10),
        _pair(
          SellerToolTile(
            icon: Icons.inventory_2_outlined,
            title: 'Add product',
            subtitle: 'List a new piece',
            onTap: onAddProduct ?? () => context.push('/create/product'),
          ),
          SellerToolTile(
            icon: Icons.auto_fix_high_outlined,
            title: kPhotoEnhancerTitle,
            subtitle: kPhotoEnhancerSubtitle,
            onTap: onPhotoEnhancer ?? () => context.push('/create/product'),
          ),
        ),
        const SizedBox(height: 10),
        SellerToolTile(
          icon: Icons.insights_outlined,
          title: 'Insights',
          subtitle: insights == null
              ? 'See how your shop is performing'
              : '${insights.postViews} post views · ${insights.followers} followers · last 30 days',
          onTap: () => context.push('/vendor/insights'),
        ),
      ],
    );
  }

  /// Two tiles side by side at the same height (subtitles may wrap).
  Widget _pair(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// One rounded tool tile (icon, title, short subtitle of up to two lines).
class SellerToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const SellerToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.sand.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.terracotta.withValues(alpha: 0.1),
                  child: Icon(icon, color: AppTheme.terracotta, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
