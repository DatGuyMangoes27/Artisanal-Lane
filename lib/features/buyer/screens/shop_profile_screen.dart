import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme.dart';
import '../../../models/models.dart';
import '../widgets/review_widgets.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/product_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/buyer_providers.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  final String shopId;

  const ShopProfileScreen({super.key, required this.shopId});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  int _selectedTab = 0; // 0 = Products, 1 = Posts, 2 = Reviews

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopDetailProvider(widget.shopId));
    final productsAsync = ref.watch(shopProductsProvider(widget.shopId));
    final postsAsync = ref.watch(shopPostsProvider(widget.shopId));
    final reviewsAsync = ref.watch(shopReviewsProvider(widget.shopId));
    final reviewSummaryAsync = ref.watch(
      shopReviewSummaryProvider(widget.shopId),
    );
    final canReviewAsync = ref.watch(canReviewShopProvider(widget.shopId));
    final marketEventsAsync = ref.watch(
      shopMarketEventsProvider(widget.shopId),
    );
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.shopId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final loadedReviews = reviewsAsync.value ?? const <ShopReview>[];
    ShopReview? myReview;
    if (currentUserId != null) {
      for (final review in loadedReviews) {
        if (review.buyerId == currentUserId) {
          myReview = review;
          break;
        }
      }
    }

    return shopAsync.when(
      data: (shop) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg, // White
        body: Stack(
          children: [
            // ── Main scrollable content ──────────────────────
            RefreshIndicator(
              color: AppTheme.terracotta,
              onRefresh: () async {
                ref.invalidate(shopDetailProvider(widget.shopId));
                ref.invalidate(shopProductsProvider(widget.shopId));
                ref.invalidate(shopPostsProvider(widget.shopId));
                ref.invalidate(shopReviewsProvider(widget.shopId));
                ref.invalidate(shopReviewSummaryProvider(widget.shopId));
                ref.invalidate(canReviewShopProvider(widget.shopId));
                ref.invalidate(shopMarketEventsProvider(widget.shopId));
                ref.invalidate(isFollowingProvider(widget.shopId));
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Hero
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _ShopHero(shop: shop),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: -60,
                          child: _MakerIdentityCard(
                            shop: shop,
                            isFollowing:
                                isFollowingAsync.asData?.value ?? false,
                            onFollowToggle: () => _toggleFollow(
                              isFollowingAsync.asData?.value ?? false,
                            ),
                            onMessageTap: () => _contactArtisan(shop),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 84)),

                  // Offline banner
                  if (shop.isOffline)
                    SliverToBoxAdapter(child: _OfflineBanner(shop: shop)),

                  // Story
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ShopStoryCard(shop: shop),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: marketEventsAsync.when(
                      data: (events) {
                        if (events.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _UpcomingMarketsCard(events: events),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Tab selector: Products / Posts
                  SliverToBoxAdapter(
                    child: _TabSelector(
                      selectedIndex: _selectedTab,
                      onChanged: (i) => setState(() => _selectedTab = i),
                    ),
                  ),

                  // ── Products tab content ──────────────────
                  if (_selectedTab == 0) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: _ShopSectionHeader(
                        title: 'Collection',
                        subtitle: 'All available works',
                        trailing: Text(
                          'Latest',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.terracotta,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    productsAsync.when(
                      data: (products) {
                        if (products.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
                              child: _EmptyCollection(
                                message:
                                    'This maker has not listed products yet.',
                              ),
                            ),
                          );
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => ProductCard(
                                product: products[index],
                                showShopName: false,
                              ),
                              childCount: products.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.65,
                                ),
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (e, _) => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: _InlineError(
                            message: 'Could not load products right now.',
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Posts tab content ─────────────────────
                  if (_selectedTab == 1) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    postsAsync.when(
                      data: (posts) {
                        if (posts.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 24, 20, 32),
                              child: _EmptyCollection(
                                message:
                                    'This maker hasn\'t shared any updates yet.\nCheck back soon!',
                              ),
                            ),
                          );
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: _PostCard(
                                  post: posts[index],
                                  shop: shop,
                                ),
                              ),
                              childCount: posts.length,
                            ),
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (e, _) => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: _InlineError(
                            message: 'Could not load posts right now.',
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_selectedTab == 2) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _ShopSectionHeader(
                              title: 'Reviews',
                              subtitle: 'What buyers are saying',
                            ),
                            reviewSummaryAsync.when(
                              data: (summary) => ReviewSummaryCard(
                                summary: summary,
                                emptyLabel: 'No reviews yet',
                              ),
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 16),
                            if (currentUserId == null)
                              _ReviewActionCard(
                                title: 'Sign in to leave a review',
                                subtitle:
                                    'Delivered orders unlock buyer reviews for this shop.',
                                buttonLabel: 'Sign In To Review',
                                onTap: () => _openShopReviewSheet(shop),
                              )
                            else if (myReview != null ||
                                (canReviewAsync.value ?? false))
                              _ReviewActionCard(
                                title: myReview != null
                                    ? 'Update your review'
                                    : 'Share your experience',
                                subtitle: myReview != null
                                    ? 'You can update your thoughts anytime.'
                                    : 'Tell other buyers about the quality, service, and packaging.',
                                buttonLabel: myReview != null
                                    ? 'Edit Review'
                                    : 'Write Review',
                                onTap: () => _openShopReviewSheet(
                                  shop,
                                  existingReview: myReview,
                                ),
                              )
                            else if (canReviewAsync.isLoading)
                              const SizedBox.shrink()
                            else
                              const _ReviewStatusNote(
                                message:
                                    'Reviews unlock after a delivered or completed order from this shop.',
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    reviewsAsync.when(
                      data: (reviews) {
                        if (reviews.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: EmptyReviewsCard(
                                title: 'No reviews yet',
                                subtitle:
                                    'Once buyers receive their orders, their reviews will appear here.',
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: BuyerReviewCard(
                                  avatarUrl: reviews[index].buyerAvatarUrl,
                                  authorName:
                                      reviews[index].buyerDisplayName ??
                                      'Verified buyer',
                                  rating: reviews[index].rating,
                                  reviewText: reviews[index].reviewText,
                                  createdAt: reviews[index].createdAt,
                                ),
                              ),
                              childCount: reviews.length,
                            ),
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (e, _) => const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: _InlineError(
                            message: 'Could not load reviews right now.',
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Center(child: TripleDot()),
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating top bar ─────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _HeroIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const Spacer(),
                      _HeroIconButton(
                        icon: Icons.share_outlined,
                        onTap: () => Share.share(
                          'Check out ${shop.name} on Artisan Lane!',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Maker Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load this maker.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to follow makers',
        message:
            'Create an account or sign in to follow this maker and keep up with new pieces.',
      );
      return;
    }

    final service = ref.read(supabaseServiceProvider);
    if (currentlyFollowing) {
      await service.unfollowShop(user.id, widget.shopId);
    } else {
      await service.followShop(user.id, widget.shopId);
    }
    ref.invalidate(isFollowingProvider(widget.shopId));
    ref.invalidate(followedShopIdsProvider);
    ref.invalidate(followerCountProvider(widget.shopId));
    ref.invalidate(followingFeedProvider);
  }

  Future<void> _contactArtisan(Shop shop) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to message artisans',
        message:
            'Create an account or sign in to start a conversation with ${shop.name}.',
      );
      return;
    }

    try {
      final thread = await ref
          .read(supabaseServiceProvider)
          .getOrCreateThread(shopId: shop.id, buyerId: user.id);
      if (mounted) {
        context.push('/profile/messages/${thread.id}');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open chat: $error',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openShopReviewSheet(
    Shop shop, {
    ShopReview? existingReview,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to leave a review',
        message:
            'Create an account or sign in to review ${shop.name} after your order is delivered.',
      );
      return;
    }

    final isEligible = await ref.read(canReviewShopProvider(shop.id).future);
    if (!isEligible && existingReview == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reviews unlock after a delivered or completed order.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    final draft = await showReviewComposerSheet(
      context,
      title: existingReview != null ? 'Edit shop review' : 'Review this shop',
      subtitle: shop.name,
      initialRating: existingReview?.rating ?? 5,
      initialReviewText: existingReview?.reviewText ?? '',
    );

    if (draft == null) {
      return;
    }

    try {
      await ref
          .read(supabaseServiceProvider)
          .submitShopReview(
            shopId: shop.id,
            buyerId: user.id,
            rating: draft.rating,
            reviewText: draft.reviewText,
          );

      ref.invalidate(shopReviewsProvider(shop.id));
      ref.invalidate(shopReviewSummaryProvider(shop.id));
      ref.invalidate(canReviewShopProvider(shop.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingReview != null
                ? 'Your review was updated.'
                : 'Thanks for sharing your review.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.baobab,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save review: $error',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════

class _ShopHero extends StatelessWidget {
  final Shop shop;

  const _ShopHero({required this.shop});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (shop.coverImageUrl != null)
            CachedNetworkImage(
              imageUrl: shop.coverImageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppTheme.bone),
              errorWidget: (_, __, ___) => Container(color: AppTheme.bone),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.terracotta,
                    AppTheme.terracotta.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _MakerIdentityCard extends StatelessWidget {
  final Shop shop;
  final bool isFollowing;
  final VoidCallback onFollowToggle;
  final VoidCallback onMessageTap;

  const _MakerIdentityCard({
    required this.shop,
    required this.isFollowing,
    required this.onFollowToggle,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    final founded = shop.createdAt.year.toString();
    final location = shop.location ?? 'South Africa';
    final countLabel = shop.productCount != null
        ? '${shop.productCount} pieces'
        : 'Collection';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.bone,
                backgroundImage: shop.logoUrl != null
                    ? CachedNetworkImageProvider(shop.logoUrl!)
                    : null,
                child: shop.logoUrl == null
                    ? Text(
                        shop.name[0],
                        style: GoogleFonts.playfairDisplay(
                          color: AppTheme.terracotta,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetaPill(icon: Icons.storefront_outlined, text: countLabel),
              const SizedBox(width: 8),
              _MetaPill(
                icon: Icons.auto_awesome_outlined,
                text: 'Since $founded',
              ),
              const Spacer(),
              _FollowButton(isFollowing: isFollowing, onTap: onFollowToggle),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _MessageButton(onTap: onMessageTap),
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;

  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isFollowing ? AppTheme.terracotta : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.terracotta, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowing ? Icons.check_rounded : Icons.add_rounded,
              size: 16,
              color: isFollowing ? Colors.white : AppTheme.terracotta,
            ),
            const SizedBox(width: 6),
            Text(
              isFollowing ? 'Following' : 'Follow',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFollowing ? Colors.white : AppTheme.terracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MessageButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bone,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.sand.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: AppTheme.terracotta,
            ),
            const SizedBox(width: 6),
            Text(
              'Message',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.terracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.terracotta),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabSelector({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTab(0, Icons.storefront_outlined, 'Products'),
          const SizedBox(width: 4),
          _buildTab(1, Icons.article_outlined, 'Posts'),
          const SizedBox(width: 4),
          _buildTab(2, Icons.reviews_outlined, 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.terracotta : AppTheme.textHint,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.terracotta : AppTheme.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ReviewActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              buttonLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStatusNote extends StatelessWidget {
  final String message;

  const _ReviewStatusNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final ShopPost post;
  final Shop shop;

  const _PostCard({required this.post, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
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
          // Post image
          if (post.mediaUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: post.primaryImage,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.bone,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.bone,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ),
            ),

          // Maker info + caption
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Maker row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.bone,
                      backgroundImage: shop.logoUrl != null
                          ? CachedNetworkImageProvider(shop.logoUrl!)
                          : null,
                      child: shop.logoUrl == null
                          ? Text(
                              shop.name[0],
                              style: GoogleFonts.playfairDisplay(
                                color: AppTheme.terracotta,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shop.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      post.timeAgo,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
                if (post.caption.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    post.caption,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopStoryCard extends StatelessWidget {
  final Shop shop;

  const _ShopStoryCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final storyText = shop.brandStory ?? shop.bio;
    if (storyText == null || storyText.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bone,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sand, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Story',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              color: AppTheme.sienna,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            storyText,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _ShopSectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                    fontSize: 22,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _UpcomingMarketsCard extends StatelessWidget {
  final List<ShopMarketEvent> events;

  const _UpcomingMarketsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    final dateFormat = DateFormat('EEE, d MMM');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.terracotta.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: AppTheme.terracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Markets',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Catch this maker in person at their next events.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bone,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.marketName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dateFormat.format(event.eventDate),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.terracotta,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.timeLabel != null &&
                        event.timeLabel!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppTheme.textHint,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            event.timeLabel!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.notes != null && event.notes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        event.notes!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: AppTheme.textHint),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final Shop shop;
  const _OfflineBanner({required this.shop});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMMM yyyy');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.terracotta.withValues(alpha: 0.12),
              AppTheme.terracotta.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.terracotta.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.do_not_disturb_on_outlined,
                size: 20,
                color: AppTheme.terracotta,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Out of Office',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.terracotta,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shop.backToWorkDate != null
                        ? 'This shop returns on ${fmt.format(shop.backToWorkDate!)}. Pre-orders are welcome!'
                        : 'This shop is temporarily offline. Pre-orders are welcome!',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
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

class _EmptyCollection extends StatelessWidget {
  final String message;
  const _EmptyCollection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sand.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            color: AppTheme.textHint,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}
