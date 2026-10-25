import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/tab_reselect.dart';
import '../../../app/theme.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/models.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/cart_nav_icon.dart';
import '../../../widgets/skeleton.dart';
import '../../auth/providers/auth_providers.dart' show currentProfileProvider;
import '../providers/blocking_providers.dart';
import '../providers/buyer_providers.dart';
import '../providers/feed_ranking.dart' show filterMutedPosts;
import '../providers/front_page_providers.dart';
import '../utils/curated_collection_destination.dart';
import '../widgets/artisan_edit_banner.dart';
import '../widgets/creator_commerce_header.dart';
import '../widgets/gift_finder_banner.dart';
import '../widgets/shop_product_tile.dart';

/// Where each front-page "See all" goes. New arrivals open the full
/// catalogue in the Shop tab, which lists newest first.
const frontPageNewArrivalsRoute = '/home/shop-all';
const frontPageArtisansRoute = '/home/shops';
const frontPageFeedRoute = '/feed';

/// The buyer app's landing tab: a welcome, a seasonal hero, new arrivals,
/// the Artisan edit, maker spotlights, the gift finder and the latest maker
/// posts, each leading to its full page. Sections with nothing to show are
/// left out.
class FrontPageScreen extends ConsumerStatefulWidget {
  const FrontPageScreen({super.key});

  @override
  ConsumerState<FrontPageScreen> createState() => _FrontPageScreenState();
}

class _FrontPageScreenState extends ConsumerState<FrontPageScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(spotlightShopsProvider);
    ref.invalidate(shopsProvider);
    try {
      await Future.wait<Object?>([
        ref.refresh(freshArrivalsProvider.future),
        ref.refresh(featuredProductsProvider.future),
        ref.refresh(frontPageSpotlightShopsProvider.future),
        ref.refresh(frontPageLatestPostsProvider.future),
      ]);
    } catch (_) {
      // Each section shows (or hides) its own failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabReselectProvider(BuyerTab.home), (_, __) {
      _scrollToTop();
    });

    final cartItems = ref.watch(cartItemsProvider).value ?? const <CartItem>[];
    final profile = ref.watch(currentProfileProvider).value;
    final hiddenShopIds = ref.watch(hiddenShopIdsProvider);
    final season = ref.watch(frontPageSeasonProvider);

    final newArrivals = ref.watch(freshArrivalsProvider);
    final featured = ref.watch(featuredProductsProvider);
    final spotlight = ref.watch(frontPageSpotlightShopsProvider);
    final posts = ref.watch(frontPageLatestPostsProvider);

    final editorial = frontPageEditorial(
      featured: featured.value ?? const [],
      newArrivals: newArrivals.value ?? const [],
    );
    final heroLoading =
        editorial.hero == null && (featured.isLoading || newArrivals.isLoading);
    final arrivals = (newArrivals.value ?? const <Product>[])
        .take(frontPageRowLimit)
        .toList();
    final makers = (spotlight.value ?? const <Shop>[])
        .where((shop) => !hiddenShopIds.contains(shop.id))
        .toList();
    final latestPosts = filterMutedPosts(
      posts.value ?? const <ShopPost>[],
      hiddenShopIds,
    ).take(frontPagePostPreviewCount).toList();
    final productsFailed =
        !newArrivals.hasValue &&
        newArrivals.hasError &&
        !featured.hasValue &&
        featured.hasError;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          backgroundColor: AppTheme.cardBg,
          onRefresh: _refresh,
          child: CustomScrollView(
            key: const Key('front-page-scroll'),
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // 1. Welcome
              SliverToBoxAdapter(
                child: CreatorCommerceHeader(
                  eyebrow: frontPageGreeting(profile?.displayName),
                  title: 'Handmade, close to home',
                  subtitle:
                      'New pieces, makers to meet and stories from their '
                      'studios.',
                  cartCount: cartBadgeCount(cartItems),
                ),
              ),

              // 2. Seasonal hero
              if (editorial.hero != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: ArtisanEditBanner(
                      key: const Key('front-hero'),
                      product: editorial.hero!,
                      eyebrow: season?.eyebrow ?? artisanEditEyebrow,
                      headline: season?.headline ?? artisanEditHeadline,
                      background: season?.background ?? AppTheme.indigo,
                      accent: season?.accent ?? AppTheme.ochre,
                    ),
                  ),
                )
              else if (heroLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Skeleton(
                      child: SkeletonBox(height: 174, radius: 24),
                    ),
                  ),
                ),

              if (productsFailed)
                SliverToBoxAdapter(
                  child: ErrorRetryView(
                    error: newArrivals.error,
                    title: "Couldn't load new pieces",
                    onRetry: () {
                      ref.invalidate(freshArrivalsProvider);
                      ref.invalidate(featuredProductsProvider);
                    },
                  ),
                ),

              // 3. New arrivals
              if (arrivals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: FrontPageSectionHeader(
                    key: const Key('front-new-arrivals'),
                    title: 'New arrivals',
                    subtitle: 'Fresh from the makers’ workbenches',
                    seeAllKey: const Key('front-new-arrivals-see-all'),
                    onSeeAll: () => context.go(frontPageNewArrivalsRoute),
                  ),
                ),
                SliverToBoxAdapter(child: _ProductRow(products: arrivals)),
              ] else if (newArrivals.isLoading)
                const SliverToBoxAdapter(child: _ProductRowSkeleton()),

              // 4. The Artisan edit (featured picks)
              if (editorial.picks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: FrontPageSectionHeader(
                    key: const Key('front-artisan-edit'),
                    title: 'The Artisan edit',
                    subtitle: 'Pieces our team loves right now',
                    seeAllKey: const Key('front-artisan-edit-see-all'),
                    onSeeAll: () => context.go(curatedCollectionRoute),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ProductRow(products: editorial.picks),
                ),
              ],

              // 5. Artisan spotlight
              if (makers.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: FrontPageSectionHeader(
                    key: const Key('front-spotlight'),
                    title: 'Artisan spotlight',
                    subtitle: 'Meet the makers behind the work',
                    seeAllKey: const Key('front-spotlight-see-all'),
                    onSeeAll: () => context.go(frontPageArtisansRoute),
                  ),
                ),
                SliverToBoxAdapter(child: _SpotlightRow(shops: makers)),
              ],

              // 6. Find a gift
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 0),
                  child: GiftFinderBanner(inkKey: Key('front-gift-finder')),
                ),
              ),

              // 7. From the makers (latest feed posts)
              if (latestPosts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: FrontPageSectionHeader(
                    key: const Key('front-from-makers'),
                    title: 'From the makers',
                    subtitle: 'Stories and updates from their studios',
                    seeAllKey: const Key('front-from-makers-see-all'),
                    onSeeAll: () => context.go(frontPageFeedRoute),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: latestPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _MakerPostPreview(post: latestPosts[index]),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: _Footer()),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Welcome back, Nicky" for a signed-in buyer with a name, otherwise a
/// general welcome.
String frontPageGreeting(String? displayName) {
  final firstName = displayName?.trim().split(RegExp(r'\s+')).first ?? '';
  return firstName.isEmpty
      ? 'Welcome to Artisan Lane'
      : 'Welcome back, $firstName';
}

/// Section title with an optional "See all" link, in the Shop tab's
/// Playfair/Poppins style.
class FrontPageSectionHeader extends StatelessWidget {
  const FrontPageSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllKey,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final Key? seeAllKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              key: seeAllKey,
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.terracotta,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const double _productCardWidth = 158;

double _productRowHeight(BuildContext context) =>
    _productCardWidth / .9 +
    shopProductDetailsHeight(MediaQuery.textScalerOf(context));

/// Horizontal row of the Shop tab's product cards.
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _productRowHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => SizedBox(
          width: _productCardWidth,
          child: ShopProductTile(
            key: ValueKey('front-product-${products[index].id}'),
            product: products[index],
          ),
        ),
      ),
    );
  }
}

class _ProductRowSkeleton extends StatelessWidget {
  const _ProductRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Skeleton(
        child: SizedBox(
          height: _productRowHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) => const SizedBox(
              width: _productCardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SkeletonBox(radius: 14)),
                  SizedBox(height: 10),
                  SkeletonBox(height: 10, width: 80),
                  SizedBox(height: 6),
                  SkeletonBox(height: 14),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _spotlightCardWidth = 264;
const double _spotlightCoverHeight = 136;

/// Horizontal row of maker cards led by each shop's cover photo.
class _SpotlightRow extends StatelessWidget {
  const _SpotlightRow({required this.shops});
  final List<Shop> shops;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final detailsHeight = scaler.scale(16) * 1.3 + 2 + scaler.scale(11) * 1.45;
    final height =
        _spotlightCoverHeight +
        28 +
        (detailsHeight > 44 ? detailsHeight : 44) +
        2;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: shops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => SizedBox(
          width: _spotlightCardWidth,
          child: _SpotlightCard(shop: shops[index]),
        ),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final cover = shop.coverImageUrl?.trim() ?? '';
    final logo = shop.logoUrl?.trim() ?? '';
    final location = shop.location?.trim() ?? '';
    final placeholder = Container(
      color: AppTheme.bone,
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_outlined,
        color: AppTheme.terracotta,
        size: 34,
      ),
    );
    return Semantics(
      button: true,
      label: 'Visit ${shop.name}',
      child: Material(
        color: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.sand.withValues(alpha: .55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('front-shop-${shop.id}'),
          onTap: () => context.push('/home/shop/${shop.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _spotlightCoverHeight,
                child: cover.isEmpty
                    ? placeholder
                    : CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ColoredBox(color: AppTheme.bone),
                        errorWidget: (_, __, ___) => placeholder,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.bone,
                      backgroundImage: logo.isEmpty
                          ? null
                          : CachedNetworkImageProvider(logo),
                      child: logo.isEmpty
                          ? Text(
                              shop.name.isEmpty ? 'A' : shop.name[0],
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.terracotta,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                                    fontSize: 16,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (shop.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: AppTheme.baobab,
                                ),
                              ],
                            ],
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 12,
                                  color: AppTheme.terracotta,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      height: 1.45,
                                      color: AppTheme.textHint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact preview of a maker post; opens the maker's page, where the full
/// post lives alongside their pieces.
class _MakerPostPreview extends StatelessWidget {
  const _MakerPostPreview({required this.post});
  final ShopPost post;

  @override
  Widget build(BuildContext context) {
    final image = post.coverImage;
    final maker = post.shopName?.trim().isNotEmpty == true
        ? post.shopName!.trim()
        : 'A local maker';
    final logo = post.shopLogoUrl?.trim() ?? '';
    final caption = post.caption.trim();
    final placeholder = Container(
      color: AppTheme.bone,
      alignment: Alignment.center,
      child: Icon(
        post.format == PostFormat.video
            ? Icons.play_circle_outline_rounded
            : Icons.dynamic_feed_outlined,
        color: AppTheme.terracotta,
        size: 28,
      ),
    );
    return Semantics(
      button: true,
      label: 'Post from $maker',
      child: Material(
        color: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppTheme.sand.withValues(alpha: .55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('front-post-${post.id}'),
          onTap: () => context.push('/home/shop/${post.shopId}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: image.isEmpty
                        ? placeholder
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const ColoredBox(color: AppTheme.bone),
                            errorWidget: (_, __, ___) => placeholder,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: AppTheme.bone,
                            backgroundImage: logo.isEmpty
                                ? null
                                : CachedNetworkImageProvider(logo),
                            child: logo.isEmpty
                                ? Text(
                                    maker[0],
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.terracotta,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              maker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (post.shopIsVerified) ...[
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.verified_rounded,
                              size: 12,
                              color: AppTheme.baobab,
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            post.timeAgo,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              color: AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        caption.isEmpty ? _formatLine(post.format) : caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          height: 1.4,
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

  static String _formatLine(PostFormat format) => switch (format) {
    PostFormat.video => 'Shared a new video',
    PostFormat.carousel => 'Shared a few new photos',
    PostFormat.tutorial => 'Shared a step-by-step',
    PostFormat.poll => 'Asked for your opinion',
    PostFormat.photo => 'Shared a new photo',
  };
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 36),
      child: Column(
        children: [
          const TripleDot(),
          const SizedBox(height: 12),
          Text(
            'Every maker has a story',
            style: GoogleFonts.playfairDisplay(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
