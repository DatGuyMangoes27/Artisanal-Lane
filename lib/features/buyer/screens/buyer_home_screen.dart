import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/unread_messages_fab.dart';
import '../../auth/providers/auth_providers.dart';
import '../utils/buyer_home_copy.dart';
import '../utils/curated_collection_carousel.dart';
import '../utils/curated_collection_destination.dart';
import '../providers/buyer_providers.dart';

class BuyerHomeScreen extends ConsumerWidget {
  const BuyerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final featured = ref.watch(featuredProductsProvider);
    final onSale = ref.watch(onSaleProductsProvider);
    final spotlightShop = ref.watch(spotlightShopProvider);
    final followingFeed = ref.watch(followingFeedProvider);
    final unreadMessages = ref.watch(buyerUnreadThreadsCountProvider);
    final profile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      floatingActionButton: unreadMessages > 0
          ? UnreadMessagesFab(
              count: unreadMessages,
              route: '/profile/messages',
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        color: AppTheme.terracotta,
        backgroundColor: AppTheme.cardBg,
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(featuredProductsProvider);
          ref.invalidate(onSaleProductsProvider);
          ref.invalidate(spotlightShopProvider);
          ref.invalidate(followingFeedProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Minimalist Header ─────────────────────────────────────────
            SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              backgroundColor: AppTheme.scaffoldBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 70,
              title: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Artisan Lane',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () => context.push('/profile/notifications'),
                  icon: const Icon(Icons.notifications_none_rounded, size: 26),
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 12),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: profile == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.displayName?.trim().isNotEmpty == true
                                ? profile.displayName!.trim()
                                : 'Ready to discover something beautiful today?',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Search Bar ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: GestureDetector(
                  onTap: () => context.go('/search'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.sand.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppTheme.terracotta,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Search for ceramics, textiles...',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textHint,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Elegant Hero ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ElegantHero(
                  onExplore: () => context.push('/home/categories'),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Curated Categories ────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: categories.when(
                  data: (cats) => ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 24),
                    itemBuilder: (context, index) {
                      final cat = cats[index];
                      return GestureDetector(
                        onTap: () => context.push(
                          '/home/category/${cat.id}?name=${cat.name}',
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppTheme.bone,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.sand.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  cat.icon,
                                  color: AppTheme.terracotta,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  loading: () => _shimmerRow(5, 64, 64, isCircle: true),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── From Makers You Follow ──────────────────────────────────
            SliverToBoxAdapter(
              child: followingFeed.when(
                data: (posts) {
                  if (posts.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BarSectionTitle(
                        title: 'From Makers You Follow',
                        subtitle: 'The latest from artisans you love',
                        onTap: () => context.go('/favourites'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 280,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (_, i) => _FeedPostCard(post: posts[i]),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Featured Collection ───────────────────────────────────────
            SliverToBoxAdapter(
              child: featured.when(
                data: (products) {
                  if (products.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: curatedCollectionTitle,
                        subtitle: curatedCollectionSubtitle,
                        onTap: () => context.push(curatedCollectionRoute),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 310,
                        child: _AutoScrollingCuratedCollection(
                          products: products,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: curatedCollectionTitle,
                      subtitle: curatedCollectionSubtitle,
                      onTap: () => context.push(curatedCollectionRoute),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(height: 310, child: _shimmerRow(3, 200, 300)),
                    const SizedBox(height: 32),
                  ],
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Meet the Makers ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: spotlightShop.when(
                data: (maker) {
                  if (maker == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Artist Spotlight',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          buyerHomeMakerSpotlightSubtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ElegantMakerSpotlight(
                          shopName: maker.name,
                          location: maker.location,
                          imageUrl: maker.coverImageUrl,
                          logoUrl: maker.logoUrl,
                          quote: maker.brandStory ?? maker.bio,
                          onTap: () => context.push('/home/shop/${maker.id}'),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [_shimmerCard(200), const SizedBox(height: 32)],
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // ── Market Specials ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Fresh Arrivals',
                subtitle: 'New pieces added to the market today',
                onTap: () => context.push('/search/results?q='),
                showDivider: true,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            onSale.when(
              data: (products) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ProductCard(product: products[index]),
                    childCount: products.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                ),
              ),
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _shimmerCard(220)),
                      const SizedBox(width: 16),
                      Expanded(child: _shimmerCard(220)),
                    ],
                  ),
                ),
              ),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // ── Footer ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    const TripleDot(),
                    const SizedBox(height: 16),
                    Text(
                      'Artisan Lane',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        color: AppTheme.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElegantHero extends StatelessWidget {
  final VoidCallback onExplore;

  const _ElegantHero({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExplore,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.terracotta, AppTheme.baobab],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.terracotta.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -50,
                  child: Opacity(
                    opacity: 0.15,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 40),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: -30,
                  child: Opacity(
                    opacity: 0.1,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          buyerHomeCategoryHeroEyebrow,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        buyerHomeCategoryHeroTitle,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        buyerHomeCategoryHeroSubtitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDivider) ...[
            const Divider(color: AppTheme.sand, thickness: 0.5),
            const SizedBox(height: 24),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.terracotta,
                  side: BorderSide(
                    color: AppTheme.terracotta.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ElegantProductCard extends StatelessWidget {
  final Product product;
  const _ElegantProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/product/${product.id}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: product.primaryImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.bone),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppTheme.bone),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_border,
                          size: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.shopName != null)
                    Text(
                      product.shopName!.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textHint,
                        letterSpacing: 0.5,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R${product.price.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.terracotta,
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
}

class _AutoScrollingCuratedCollection extends StatefulWidget {
  final List<Product> products;

  const _AutoScrollingCuratedCollection({required this.products});

  @override
  State<_AutoScrollingCuratedCollection> createState() =>
      _AutoScrollingCuratedCollectionState();
}

class _AutoScrollingCuratedCollectionState
    extends State<_AutoScrollingCuratedCollection> {
  late final ScrollController _controller;
  Timer? _scrollTimer;
  Timer? _resumeTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void didUpdateWidget(covariant _AutoScrollingCuratedCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products.length != widget.products.length) {
      _stopTimers();
      _isPaused = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
    }
  }

  void _startAutoScroll() {
    if (!mounted || !shouldAutoScrollCuratedCollection(widget.products.length)) {
      return;
    }

    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(curatedCollectionTick, (_) {
      if (!mounted || _isPaused || !_controller.hasClients) return;

      final position = _controller.position;
      final maxScrollExtent = position.maxScrollExtent;
      if (maxScrollExtent <= 0) return;

      final nextOffset = _controller.offset + curatedCollectionScrollStep;
      if (nextOffset >= maxScrollExtent) {
        _controller.jumpTo(0);
      } else {
        _controller.jumpTo(nextOffset);
      }
    });
  }

  void _pauseAutoScroll() {
    _isPaused = true;
    _resumeTimer?.cancel();
  }

  void _scheduleResume() {
    if (!shouldAutoScrollCuratedCollection(widget.products.length)) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(curatedCollectionResumeDelay, () {
      _isPaused = false;
    });
  }

  void _stopTimers() {
    _scrollTimer?.cancel();
    _resumeTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _pauseAutoScroll(),
      onPointerUp: (_) => _scheduleResume(),
      onPointerCancel: (_) => _scheduleResume(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            _pauseAutoScroll();
          } else if (notification is ScrollEndNotification) {
            _scheduleResume();
          }
          return false;
        },
        child: ListView.separated(
          controller: _controller,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: widget.products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, i) => _ElegantProductCard(product: widget.products[i]),
        ),
      ),
    );
  }
}

class _BarSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BarSectionTitle({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppTheme.ochre,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 21,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppTheme.textHint,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.terracotta,
                    side: BorderSide(
                      color: AppTheme.terracotta.withValues(alpha: 0.45),
                    ),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'See All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  final ShopPost post;
  const _FeedPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/home/shop/${post.shopId}'),
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with maker avatar pill overlay
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.primaryImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.bone),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppTheme.bone),
                    ),
                    // Maker pill overlaid on the image
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: AppTheme.bone,
                              backgroundImage: post.shopLogoUrl != null
                                  ? CachedNetworkImageProvider(
                                      post.shopLogoUrl!,
                                    )
                                  : null,
                              child: post.shopLogoUrl == null
                                  ? Text(
                                      (post.shopName ?? '?')[0],
                                      style: GoogleFonts.poppins(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.terracotta,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                post.shopName ?? 'Artisan',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Caption
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  post.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            // Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                post.timeAgo,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppTheme.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElegantMakerSpotlight extends StatelessWidget {
  final String shopName;
  final String? location;
  final String? imageUrl;
  final String? logoUrl;
  final String? quote;
  final VoidCallback onTap;

  const _ElegantMakerSpotlight({
    required this.shopName,
    required this.location,
    required this.imageUrl,
    required this.logoUrl,
    required this.quote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: imageUrl == null
                    ? Container(color: AppTheme.bone)
                    : CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppTheme.bone),
                        errorWidget: (_, __, ___) =>
                            Container(color: AppTheme.bone),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.bone,
                        backgroundImage: logoUrl == null
                            ? null
                            : CachedNetworkImageProvider(logoUrl!),
                        child: logoUrl == null
                            ? Text(
                                shopName.isEmpty ? '?' : shopName[0],
                                style: GoogleFonts.playfairDisplay(
                                  color: AppTheme.terracotta,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shopName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (location != null)
                              Text(
                                location!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.textHint,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    quote ?? 'Crafting with tradition and heart.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _shimmerRow(
  int count,
  double width,
  double height, {
  bool isCircle = false,
}) {
  return ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    scrollDirection: Axis.horizontal,
    itemCount: count,
    separatorBuilder: (_, __) => SizedBox(width: isCircle ? 24 : 16),
    itemBuilder: (_, __) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.bone,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(12),
      ),
    ),
  );
}

Widget _shimmerCard(double height) {
  return Container(
    height: height,
    decoration: BoxDecoration(
      color: AppTheme.bone,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}
