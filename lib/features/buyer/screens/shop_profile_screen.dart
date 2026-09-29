import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/models.dart';
import '../widgets/creator_feed/creator_feed_post_card.dart';
import '../widgets/review_widgets.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../../widgets/african_patterns.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/skeleton.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/buyer_providers.dart';
import '../providers/creator_parity_providers.dart';
import '../utils/shop_profile_actions.dart';
import '../widgets/content_report_sheet.dart';
import '../../vendor/services/creator_post_media.dart';
import '../../../services/content_view_session.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  final String shopId;

  const ShopProfileScreen({super.key, required this.shopId});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  int _selectedTab = 0; // 0 = Products, 1 = Posts, 2 = Reviews
  bool? _followOptimistic;
  bool _isTogglingFollow = false;

  @override
  void initState() {
    super.initState();
    // Best effort; recordContentView never throws for the caller.
    Future.microtask(() async {
      try {
        await recordContentView(ref, 'shop', widget.shopId);
      } catch (_) {}
    });
  }

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
    final followerCount = ref
        .watch(followerCountProvider(widget.shopId))
        .asData
        ?.value;
    final currentUserId = ref.watch(currentUserIdProvider);
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
      data: (shop) {
        final isOwnShop =
            currentUserId != null && currentUserId == shop.vendorId;
        return Scaffold(
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
                              followerCount: followerCount,
                              postsCount: postsAsync.asData?.value.length,
                              productsCount: productsAsync.asData?.value.length,
                              isFollowing:
                                  _followOptimistic ??
                                  (isFollowingAsync.asData?.value ?? false),
                              onFollowToggle: () => _toggleFollow(
                                _followOptimistic ??
                                    (isFollowingAsync.asData?.value ?? false),
                              ),
                              onMessageTap: () => _contactArtisan(shop),
                              isOwnShop: isOwnShop,
                              onInsightsTap: () =>
                                  context.push('/vendor/insights'),
                              onEditShopTap: () =>
                                  context.push('/vendor/profile/shop'),
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
                        error: (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: _InlineError(
                              message: 'Could not load products right now.',
                              onRetry: () => ref.invalidate(
                                shopProductsProvider(widget.shopId),
                              ),
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
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _PostGridTile(
                                  post: posts[index],
                                  onTap: () => _openPost(posts[index], shop),
                                ),
                                childCount: posts.length,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 4,
                                    crossAxisSpacing: 4,
                                    childAspectRatio: 1,
                                  ),
                            ),
                          );
                        },
                        loading: () => const SliverPadding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: _PostsGridSkeleton(),
                        ),
                        error: (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: _InlineError(
                              message: 'Could not load posts right now.',
                              onRetry: () => ref.invalidate(
                                shopPostsProvider(widget.shopId),
                              ),
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
                        error: (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: _InlineError(
                              message: 'Could not load reviews right now.',
                              onRetry: () => ref.invalidate(
                                shopReviewsProvider(widget.shopId),
                              ),
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
                        _ShopMoreMenuButton(shop: shop, isOwnShop: isOwnShop),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: const SafeArea(child: _ShopProfileSkeleton()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Maker Profile'),
        ),
        body: ErrorRetryView(
          error: error,
          title: "Couldn't load this maker",
          onRetry: () => ref.invalidate(shopDetailProvider(widget.shopId)),
        ),
      ),
    );
  }

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_isTogglingFollow) return;
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

    final nextFollowing = !currentlyFollowing;
    HapticFeedback.lightImpact();
    setState(() {
      _isTogglingFollow = true;
      _followOptimistic = nextFollowing;
    });

    try {
      final service = ref.read(supabaseServiceProvider);
      if (nextFollowing) {
        await service.followShop(user.id, widget.shopId);
      } else {
        await service.unfollowShop(user.id, widget.shopId);
      }
      ref.invalidate(isFollowingProvider(widget.shopId));
      ref.invalidate(followedShopIdsProvider);
      ref.invalidate(followerCountProvider(widget.shopId));
      ref.invalidate(followingFeedProvider);
      if (mounted) {
        setState(() {
          _isTogglingFollow = false;
          _followOptimistic = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTogglingFollow = false;
        _followOptimistic = currentlyFollowing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: nextFollowing
                  ? "Couldn't follow this maker. Please try again."
                  : "Couldn't unfollow this maker. Please try again.",
            ),
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openPost(ShopPost post, Shop shop) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ShopPostViewerScreen(
          post: post,
          shopId: widget.shopId,
          onFollowToggle: (currentlyFollowing) =>
              _toggleFollow(currentlyFollowing),
        ),
      ),
    );
  }

  Future<void> _contactArtisan(Shop shop) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    try {
      await handleShopMessageTap(
        userId: userId,
        promptSignIn: () => showSignInPromptSheet(
          context,
          title: 'Sign in to message artisans',
          message:
              'Create an account or sign in to start a conversation with ${shop.name}.',
        ),
        createOrGetThreadId: (buyerId) async {
          final thread = await ref
              .read(supabaseServiceProvider)
              .getOrCreateThread(shopId: shop.id, buyerId: buyerId);
          return thread.id;
        },
        openChat: (route) async {
          if (!mounted) return;
          await context.push(route);
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(error, fallback: 'Could not open chat.'),
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
            friendlyErrorMessage(error, fallback: 'Could not save review.'),
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

enum _ShopMoreMenuAction { copyLink, share, mute, report }

/// The maker profile's ⋯ menu: copy link, share, mute/unmute this maker,
/// and (when [creatorSafetyEnabled] and signed in, never on your own shop)
/// report this maker.
class _ShopMoreMenuButton extends ConsumerWidget {
  final Shop shop;
  final bool isOwnShop;

  const _ShopMoreMenuButton({required this.shop, required this.isOwnShop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(currentUserIdProvider) != null;
    final isMuted = ref.watch(isShopMutedProvider(shop.id));
    final canModerate = isSignedIn && !isOwnShop;
    return PopupMenuButton<_ShopMoreMenuAction>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _ShopMoreMenuAction.copyLink,
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: AppTheme.textPrimary),
              SizedBox(width: 10),
              Text('Copy link'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _ShopMoreMenuAction.share,
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 18, color: AppTheme.textPrimary),
              SizedBox(width: 10),
              Text('Share'),
            ],
          ),
        ),
        if (canModerate)
          PopupMenuItem(
            value: _ShopMoreMenuAction.mute,
            child: Row(
              children: [
                Icon(
                  isMuted
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  size: 18,
                  color: AppTheme.textPrimary,
                ),
                const SizedBox(width: 10),
                Text(isMuted ? 'Unmute' : 'Mute'),
              ],
            ),
          ),
        if (creatorSafetyEnabled && canModerate)
          const PopupMenuItem(
            value: _ShopMoreMenuAction.report,
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: AppTheme.error),
                SizedBox(width: 10),
                Text('Report', style: TextStyle(color: AppTheme.error)),
              ],
            ),
          ),
      ],
      onSelected: (action) async {
        switch (action) {
          case _ShopMoreMenuAction.copyLink:
            await Clipboard.setData(
              ClipboardData(
                text: '$shopShareBaseUrl/${Uri.encodeComponent(shop.id)}',
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            break;
          case _ShopMoreMenuAction.share:
            await Share.share(
              buildShopShareText(shopId: shop.id, shopName: shop.name),
            );
            break;
          case _ShopMoreMenuAction.mute:
            await setShopMuted(
              ref,
              context,
              shop.id,
              muted: !isMuted,
              shopName: shop.name,
            );
            break;
          case _ShopMoreMenuAction.report:
            await showContentReportSheet(
              context,
              shopId: shop.id,
              targetId: shop.id,
            );
            break;
        }
      },
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
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _MakerIdentityCard extends StatelessWidget {
  final Shop shop;
  final int? followerCount;
  final int? postsCount;
  final int? productsCount;
  final bool isFollowing;
  final VoidCallback onFollowToggle;
  final VoidCallback onMessageTap;
  final bool isOwnShop;
  final VoidCallback? onInsightsTap;
  final VoidCallback? onEditShopTap;

  const _MakerIdentityCard({
    required this.shop,
    required this.followerCount,
    this.postsCount,
    this.productsCount,
    required this.isFollowing,
    required this.onFollowToggle,
    required this.onMessageTap,
    this.isOwnShop = false,
    this.onInsightsTap,
    this.onEditShopTap,
  });

  @override
  Widget build(BuildContext context) {
    final founded = shop.createdAt.year.toString();
    final location = shop.location ?? 'South Africa';

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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
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
                        ),
                        if (shop.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified,
                            color: AppTheme.baobab,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shop.handle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textHint,
                        fontWeight: FontWeight.w500,
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
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
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
          _ProfileStatsRow(
            followerCount: followerCount,
            productsCount: productsCount,
            postsCount: postsCount,
          ),
          const SizedBox(height: 6),
          Text(
            'Since $founded',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textHint),
          ),
          const SizedBox(height: 14),
          if (isOwnShop) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onInsightsTap,
                    icon: const Icon(Icons.insights_outlined, size: 17),
                    label: const Text('Insights'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEditShopTap,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit shop'),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: _FollowButton(
                isFollowing: isFollowing,
                onTap: onFollowToggle,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _MessageButton(onTap: onMessageTap),
            ),
          ],
        ],
      ),
    );
  }
}

/// Instagram-style profile counts: value above label, evenly spaced.
/// Followers stay hidden at zero so a brand-new shop doesn't read as empty.
class _ProfileStatsRow extends StatelessWidget {
  final int? followerCount;
  final int? productsCount;
  final int? postsCount;

  const _ProfileStatsRow({
    required this.followerCount,
    required this.productsCount,
    required this.postsCount,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      if ((followerCount ?? 0) > 0)
        (
          _compactCount(followerCount!),
          followerCount == 1 ? 'follower' : 'followers',
        ),
      (_compactCount(productsCount ?? 0), 'products'),
      (_compactCount(postsCount ?? 0), 'posts'),
    ];
    return Row(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.$1,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  entry.$2,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _compactCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;

  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isFollowing ? AppTheme.terracotta : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.terracotta, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
    return Material(
      color: AppTheme.bone,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
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

/// Square thumbnail tile for the Posts grid. Videos show a play icon over
/// their cover image rather than a "Private video" wall of text — the post
/// is still visible to buyers, only the raw file access is private.
class _PostGridTile extends StatelessWidget {
  final ShopPost post;
  final VoidCallback onTap;

  const _PostGridTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                  size: 30,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostsGridSkeleton extends StatelessWidget {
  const _PostsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Skeleton(child: SkeletonBox(radius: 0)),
        childCount: 9,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
    );
  }
}

/// Full-screen viewer for a single maker post, opened by tapping a tile in
/// the Posts grid. Reuses [CreatorFeedPostCard] so a post looks the same
/// here as it does in the creator feed.
class _ShopPostViewerScreen extends ConsumerWidget {
  final ShopPost post;
  final String shopId;
  final Future<void> Function(bool currentlyFollowing) onFollowToggle;

  const _ShopPostViewerScreen({
    required this.post,
    required this.shopId,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onFollowToggle: () => onFollowToggle(isFollowing),
          ),
        ),
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
    final hasStory = storyText != null && storyText.trim().isNotEmpty;
    final avatarUrl = shop.artisanAvatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    if (!hasStory && !hasAvatar) {
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
          Row(
            children: [
              if (hasAvatar) ...[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.sand,
                  backgroundImage: CachedNetworkImageProvider(avatarUrl),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
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
                    if (hasAvatar && shop.artisanName != null)
                      Text(
                        'with ${shop.artisanName}',
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
          if (hasStory) ...[
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
  final VoidCallback? onRetry;
  const _InlineError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: AppTheme.textHint),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try again'),
              ),
            ],
          ],
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

/// Shimmering placeholder for the maker profile while it first loads, so
/// the screen never sits on a bare spinner.
class _ShopProfileSkeleton extends StatelessWidget {
  const _ShopProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 76, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SkeletonBox(width: 60, height: 60, circle: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 160, height: 20),
                        SizedBox(height: 8),
                        SkeletonBox(width: 100, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SkeletonBox(width: double.infinity, height: 44),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: SkeletonBox(height: 220)),
                  const SizedBox(width: 12),
                  Expanded(child: SkeletonBox(height: 220)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
