import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tab_reselect.dart';
import '../../../app/theme.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/ui/friendly_error.dart';
import '../../../models/cart_item.dart';
import '../../../models/product.dart';
import '../../../models/shop_post.dart';
import '../../../services/content_view_session.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../../widgets/skeleton.dart';
import '../../vendor/services/creator_post_media.dart'
    show isCreatorPostMediaMarker;
import '../providers/blocking_providers.dart';
import '../providers/buyer_providers.dart';
import '../providers/creator_parity_providers.dart';
import '../providers/feed_preferences.dart';
import '../providers/feed_ranking.dart';
import '../providers/feed_video_playback.dart';
import '../utils/discovery_preferences.dart';
import '../utils/feed_pagination.dart';
import '../widgets/creator_feed/creator_feed_media_viewer.dart'
    show isCreatorFeedVideoUrl;
import '../widgets/creator_feed/creator_feed_post_card.dart';
import '../widgets/creator_story_rail.dart';
import '../widgets/creator_compose_button.dart';
import '../providers/story_providers.dart';
import '../widgets/creator_commerce_header.dart';
import '../../../widgets/cart_nav_icon.dart';

enum _FeedMode { forYou, following }

class CreatorFeedScreen extends ConsumerStatefulWidget {
  const CreatorFeedScreen({super.key});

  @override
  ConsumerState<CreatorFeedScreen> createState() => _CreatorFeedScreenState();
}

class _CreatorFeedScreenState extends ConsumerState<CreatorFeedScreen> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  _FeedMode _mode = _FeedMode.forYou;
  final _posts = <ShopPost>[];
  final _followedShopIds = <String>{};
  var _isInitialLoading = true;
  var _isLoadingMore = false;
  Object? _error;
  Object? _loadMoreError;
  var _hasMore = true;
  var _requestGeneration = 0;
  // Keyset cursor: the last post the server returned, so the next page asks
  // for strictly older posts instead of an offset that drifts when posts
  // are published, removed or dropped locally.
  FeedCursor? _cursor;
  // Which loaded page each post arrived in. "For you" ranks page by page so
  // a new page can never reshuffle posts the buyer already scrolled past.
  final _pageOfPost = <String, int>{};
  var _pageCount = 0;
  // Pinned clock for ranking so the order doesn't drift between rebuilds.
  var _rankedAt = DateTime.now();
  final _followRequests = <String>{};
  final _cardKeys = <String, GlobalKey>{};
  final _viewedPostIds = <String>{};
  final _viewTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ref.listenManual<String?>(currentUserIdProvider, (previous, next) {
      if (previous != next && mounted) _reload();
    });
    ref.listenManual<int>(tabReselectProvider(BuyerTab.feed), (previous, next) {
      if (previous != null && previous != next && mounted) _scrollToTop();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reload();
      }
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final timer in _viewTimers.values) {
      timer.cancel();
    }
    _viewTimers.clear();
    super.dispose();
  }

  void _onScroll() {
    if (_loadMoreError == null &&
        _scrollController.position.extentAfter < 500) {
      _loadMore();
    }
    _updateActiveVideo();
    _updateContentViews();
  }

  /// Records one view per post per session, once its card has been at
  /// least [feedVideoVisibilityThreshold] visible for about a second.
  /// Cheap geometry only, reusing the same card keys the video autoplay
  /// tracker already maintains; never blocks scrolling or interaction.
  void _updateContentViews() {
    if (!mounted) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    for (final post in _posts) {
      if (_viewedPostIds.contains(post.id)) continue;
      final renderObject = _cardKeys[post.id]?.currentContext
          ?.findRenderObject();
      var fraction = 0.0;
      if (renderObject is RenderBox && renderObject.attached) {
        fraction = visibleFraction(
          itemTop: renderObject.localToGlobal(Offset.zero).dy,
          itemHeight: renderObject.size.height,
          viewportHeight: viewportHeight,
        );
      }
      final visible = fraction >= feedVideoVisibilityThreshold;
      if (visible) {
        _viewTimers.putIfAbsent(
          post.id,
          () => Timer(const Duration(seconds: 1), () {
            _viewTimers.remove(post.id);
            if (!mounted || _viewedPostIds.contains(post.id)) return;
            _viewedPostIds.add(post.id);
            recordContentView(ref, 'post', post.id);
          }),
        );
      } else {
        _viewTimers.remove(post.id)?.cancel();
      }
    }
  }

  bool _postHasVideo(ShopPost post) => post.mediaUrls.any(
    (url) => isCreatorPostMediaMarker(url.trim()) || isCreatorFeedVideoUrl(url),
  );

  /// Finds the single loaded video post that's at least
  /// [feedVideoVisibilityThreshold] visible in the viewport and marks it as
  /// the one allowed to autoplay. Cheap geometry only — no new packages.
  void _updateActiveVideo() {
    if (!creatorVideoPostsEnabled || !mounted) return;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    String? bestId;
    var bestFraction = feedVideoVisibilityThreshold;
    for (final post in _posts) {
      if (!_postHasVideo(post)) continue;
      final renderObject = _cardKeys[post.id]?.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final fraction = visibleFraction(
        itemTop: renderObject.localToGlobal(Offset.zero).dy,
        itemHeight: renderObject.size.height,
        viewportHeight: viewportHeight,
      );
      if (fraction >= bestFraction) {
        bestFraction = fraction;
        bestId = post.id;
      }
    }
    ref.read(activeFeedVideoPostIdProvider.notifier).setActive(bestId);
  }

  Future<void> _reload() async {
    ref.invalidate(storiesProvider);
    ref.invalidate(seenStoriesProvider);
    final generation = ++_requestGeneration;
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _error = null;
      _hasMore = true;
      _loadMoreError = null;
    });
    try {
      final posts = await _fetchPosts();
      final followedIds = await _fetchFollowedIds();
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(dedupePostsById(posts));
        _pageOfPost
          ..clear()
          ..addAll({for (final post in _posts) post.id: 0});
        _pageCount = 1;
        _cursor = FeedCursor.after(posts);
        _rankedAt = DateTime.now();
        _followedShopIds
          ..clear()
          ..addAll(followedIds);
        _hasMore = posts.length == _pageSize;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isInitialLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateActiveVideo();
          _updateContentViews();
        });
      }
    }
  }

  Future<void> _loadMore({bool retry = false}) async {
    if (_isInitialLoading ||
        _isLoadingMore ||
        !_hasMore ||
        _error != null ||
        (!retry && _loadMoreError != null)) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      if (retry) {
        _loadMoreError = null;
      }
    });
    final generation = _requestGeneration;
    try {
      final next = await _fetchPosts(cursor: _cursor);
      if (mounted && generation == _requestGeneration) {
        setState(() {
          // Belt and braces on top of the keyset cursor: never show the
          // same post twice.
          final page = _pageCount++;
          for (final post in appendUniquePosts(_posts, next)) {
            _pageOfPost[post.id] = page;
          }
          _cursor = FeedCursor.after(next) ?? _cursor;
          _hasMore = next.length == _pageSize;
        });
      }
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadMoreError = error);
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoadingMore = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateActiveVideo();
          _updateContentViews();
        });
      }
    }
  }

  Future<List<ShopPost>> _fetchPosts({FeedCursor? cursor}) async {
    final service = ref.read(supabaseServiceProvider);
    final userId = ref.read(currentUserIdProvider);
    if (_mode == _FeedMode.following) {
      if (userId == null) return [];
      return service.getFollowingFeed(
        userId,
        limit: _pageSize,
        before: cursor,
      );
    }
    var query = ref
        .read(supabaseClientProvider)
        .from('shop_posts')
        .select(ShopPost.select)
        .eq('is_published', true);
    if (cursor != null) query = query.or(cursor.olderThanFilter);
    final data = await query
        .order('published_at', ascending: false)
        .order('id', ascending: false)
        .limit(_pageSize);
    return (data as List)
        .map((row) => ShopPost.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> _fetchFollowedIds() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return [];
    return ref.read(supabaseServiceProvider).getFollowedShopIds(userId);
  }

  Future<void> _changeMode(_FeedMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    await _reload();
  }

  /// Assembles the "For you" ranking signals purely from data this screen
  /// (or providers it already reads) already has loaded — no new fetches.
  FeedRankingSignals _buildRankingSignals() {
    final favourites =
        ref.watch(favouriteProductsProvider).value ?? const <Product>[];
    final discoverPrefs = ref.watch(discoveryPreferencesProvider).value;
    final shapePrefs =
        ref.watch(feedPreferencesProvider).value ?? const FeedPreferences();
    final catalogPools = <Product>[
      ...favourites,
      ...ref.watch(featuredProductsProvider).value ?? const [],
      ...ref.watch(curatedCollectionProductsProvider).value ?? const [],
      ...ref.watch(onSaleProductsProvider).value ?? const [],
      ...ref.watch(freshArrivalsProvider).value ?? const [],
    ];
    final categoryByProduct = <String, String>{};
    for (final product in catalogPools) {
      final categoryId = product.categoryId;
      if (categoryId != null) categoryByProduct[product.id] = categoryId;
    }
    return FeedRankingSignals(
      followedShopIds: _followedShopIds,
      favouritedShopIds: favourites.map((p) => p.shopId).toSet(),
      likedCategoryIds: discoverPrefs?.categoryIds ?? const <String>{},
      likedProductIds: discoverPrefs?.likedProductIds ?? const <String>{},
      categoryIdsByProductId: categoryByProduct,
      mutedShopIds: shapePrefs.mutedShopIds,
      boostedCategoryIds: shapePrefs.boostedCategoryIds,
      now: _rankedAt,
    );
  }

  Future<void> _showShapeYourFeedSheet() async {
    final makers = <String, String>{};
    for (final post in _posts) {
      makers.putIfAbsent(
        post.shopId,
        () => post.shopName?.trim().isNotEmpty == true
            ? post.shopName!
            : 'This maker',
      );
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => TuneYourFeedSheet(makers: makers),
    );
  }

  Future<void> _toggleFollow(ShopPost post) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      await showSignInPromptSheet(
        context,
        title: 'Sign in to follow makers',
        message:
            'Create an account or sign in to keep up with new pieces from your favourite makers.',
      );
      return;
    }
    if (_followRequests.contains(post.shopId)) return;
    _followRequests.add(post.shopId);
    final isFollowing = _followedShopIds.contains(post.shopId);
    final service = ref.read(supabaseServiceProvider);
    HapticFeedback.selectionClick();
    // Flip instantly; roll back only if the request fails. Unfollowing in
    // the Following tab just drops that maker's posts locally — no reload,
    // no jump to the top.
    final removedPosts = <int, ShopPost>{};
    setState(() {
      if (isFollowing) {
        _followedShopIds.remove(post.shopId);
        if (_mode == _FeedMode.following) {
          for (var i = _posts.length - 1; i >= 0; i--) {
            if (_posts[i].shopId == post.shopId) {
              removedPosts[i] = _posts[i];
              _posts.removeAt(i);
            }
          }
        }
      } else {
        _followedShopIds.add(post.shopId);
      }
    });
    try {
      if (isFollowing) {
        await service.unfollowShop(userId, post.shopId);
      } else {
        await service.followShop(userId, post.shopId);
      }
      if (!mounted || ref.read(currentUserIdProvider) != userId) return;
      ref.invalidate(followedShopIdsProvider);
      ref.invalidate(isFollowingProvider(post.shopId));
      ref.invalidate(followingFeedProvider);
    } catch (_) {
      if (mounted && ref.read(currentUserIdProvider) == userId) {
        setState(() {
          if (isFollowing) {
            _followedShopIds.add(post.shopId);
            for (final entry
                in removedPosts.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key))) {
              _posts.insert(entry.key.clamp(0, _posts.length), entry.value);
            }
          } else {
            _followedShopIds.remove(post.shopId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this follow. Please try again.'),
          ),
        );
      }
    } finally {
      _followRequests.remove(post.shopId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hiddenShopIds = ref.watch(hiddenShopIdsProvider);
    final visiblePosts = filterMutedPosts(_posts, hiddenShopIds);
    final displayPosts = _mode == _FeedMode.forYou
        ? rankForYouFeedByPage(
            visiblePosts,
            _pageOfPost,
            _buildRankingSignals(),
          )
        : visiblePosts;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: _reload,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _FeedHeader(
                  mode: _mode,
                  onModeChanged: _changeMode,
                  onCreated: _reload,
                  onShapeFeed: _showShapeYourFeedSheet,
                  cartCount: cartBadgeCount(
                    ref.watch(cartItemsProvider).value ?? const <CartItem>[],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: CreatorStoryRail()),
              if (_isInitialLoading)
                const SliverToBoxAdapter(child: _FeedSkeleton())
              else if (_error != null)
                SliverFillRemaining(
                  child: ErrorRetryView(
                    error: _error,
                    title: 'We could not load the feed.',
                    onRetry: _reload,
                  ),
                )
              else if (_posts.isEmpty)
                SliverFillRemaining(
                  child: _FeedEmpty(
                    mode: _mode,
                    signedIn: ref.watch(currentUserIdProvider) != null,
                    onBrowse: () => _changeMode(_FeedMode.forYou),
                  ),
                )
              else ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == displayPosts.length) {
                      if (_loadMoreError != null) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          child: OutlinedButton.icon(
                            onPressed: () => _loadMore(retry: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Could not load more. Retry'),
                          ),
                        );
                      }
                      return _isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox(height: 20);
                    }
                    final post = displayPosts[index];
                    final key = _cardKeys.putIfAbsent(
                      post.id,
                      () => GlobalKey(debugLabel: 'feed-post-${post.id}'),
                    );
                    return CreatorFeedPostCard(
                      key: key,
                      post: post,
                      isFollowing: _followedShopIds.contains(post.shopId),
                      onOpenShop: () =>
                          context.push('/home/shop/${post.shopId}'),
                      onFollowToggle: () => _toggleFollow(post),
                    );
                  }, childCount: displayPosts.length + 1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.mode,
    required this.onModeChanged,
    required this.cartCount,
    required this.onCreated,
    required this.onShapeFeed,
  });
  final _FeedMode mode;
  final ValueChanged<_FeedMode> onModeChanged;
  final int cartCount;
  final Future<void> Function() onCreated;
  final VoidCallback onShapeFeed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CreatorCommerceHeader(
          eyebrow: 'Artisan Lane',
          title: 'Made with a story',
          subtitle: 'Updates shared directly by local makers.',
          cartCount: cartCount,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FeedPill(
                label: 'For you',
                selected: mode == _FeedMode.forYou,
                onTap: () => onModeChanged(_FeedMode.forYou),
              ),
              const SizedBox(width: 8),
              _FeedPill(
                label: 'Following',
                selected: mode == _FeedMode.following,
                onTap: () => onModeChanged(_FeedMode.following),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CreatorComposeButton(onFinished: onCreated),
                ),
              ),
              IconButton(
                key: const Key('shape-your-feed-button'),
                tooltip: 'Tune your feed',
                onPressed: onShapeFeed,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FeedPill extends StatelessWidget {
  const _FeedPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppTheme.terracotta : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? AppTheme.terracotta : AppTheme.sand,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// "Tune your feed" bottom sheet: personal, on-device choices that steer
/// the "For you" ranking without unfollowing anyone. [makers] is the set of
/// makers currently visible in the loaded feed (shop id to name).
class TuneYourFeedSheet extends ConsumerWidget {
  const TuneYourFeedSheet({super.key, required this.makers});
  final Map<String, String> makers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final preferences =
        ref.watch(feedPreferencesProvider).value ?? const FeedPreferences();
    final notifier = ref.read(feedPreferencesProvider.notifier);
    final mutedShopIds =
        ref.watch(mutedShopIdsProvider).value ?? const <String>{};
    final sortedMakers = makers.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final helperStyle = textTheme.bodySmall?.copyWith(
      height: 1.45,
      color: AppTheme.textSecondary,
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tune your feed', style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Choose what you see more and less of in For you. Only you '
                'see these choices, and they stay on this device.',
                style: helperStyle,
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('See more of', style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Pick the categories you like and their posts move up.',
                  style: helperStyle,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map(
                        (category) => FilterChip(
                          key: Key('shape-feed-category-${category.id}'),
                          label: Text(category.name),
                          selected: preferences.boostedCategoryIds.contains(
                            category.id,
                          ),
                          onSelected: (_) =>
                              notifier.toggleBoostedCategory(category.id),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (sortedMakers.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('Makers in your feed', style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Turn a maker off to see fewer of their posts. You will '
                  'still follow them.',
                  style: helperStyle,
                ),
                const SizedBox(height: 4),
                ...sortedMakers.map((entry) {
                  final showingFewer = preferences.mutedShopIds.contains(
                    entry.key,
                  );
                  return SwitchListTile(
                    key: Key('shape-feed-mute-${entry.key}'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppTheme.terracotta,
                    title: Text(entry.value),
                    subtitle: Text(
                      showingFewer ? 'Showing fewer posts' : 'Showing as usual',
                      style: textTheme.bodySmall?.copyWith(
                        color: showingFewer
                            ? AppTheme.terracotta
                            : AppTheme.textSecondary,
                        fontWeight: showingFewer ? FontWeight.w600 : null,
                      ),
                    ),
                    value: !showingFewer,
                    onChanged: (show) => show
                        ? notifier.unmuteShop(entry.key)
                        : notifier.muteShop(entry.key),
                  );
                }),
              ],
              if (mutedShopIds.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('Muted makers', style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  "You won't see posts or stories from these makers.",
                  style: helperStyle,
                ),
                const SizedBox(height: 6),
                ...mutedShopIds.map(
                  (shopId) => ListTile(
                    key: Key('shape-feed-unmute-$shopId'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(makers[shopId] ?? 'This maker'),
                    trailing: OutlinedButton(
                      onPressed: () => setShopMuted(
                        ref,
                        context,
                        shopId,
                        muted: false,
                        shopName: makers[shopId],
                      ),
                      child: const Text('Unmute'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('tune-feed-done'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty({
    required this.mode,
    required this.signedIn,
    required this.onBrowse,
  });
  final _FeedMode mode;
  final bool signedIn;
  final VoidCallback onBrowse;
  @override
  Widget build(BuildContext context) {
    final following = mode == _FeedMode.following;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              following
                  ? Icons.people_outline_rounded
                  : Icons.auto_awesome_outlined,
              size: 48,
              color: AppTheme.terracotta,
            ),
            const SizedBox(height: 16),
            Text(
              following
                  ? (signedIn
                        ? 'Your following feed is ready for makers.'
                        : 'Sign in to see makers you follow.')
                  : 'No maker posts yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              following
                  ? 'Follow a maker from any post and their future updates will appear here.'
                  : 'Check back soon for new workshop stories and pieces.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (following) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onBrowse,
                child: const Text('Browse maker posts'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();
  @override
  Widget build(BuildContext context) =>
      Column(children: List.generate(3, (_) => const _FeedSkeletonCard()));
}

class _FeedSkeletonCard extends StatelessWidget {
  const _FeedSkeletonCard();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 7, 16, 12),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.clay),
    ),
    clipBehavior: Clip.antiAlias,
    child: Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const SkeletonBox(width: 44, height: 44, circle: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 14, radius: 6),
                      const SizedBox(height: 6),
                      SkeletonBox(width: 70, height: 10, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const AspectRatio(aspectRatio: 1.06, child: SkeletonBox(radius: 0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SkeletonBox(width: double.infinity, height: 14, radius: 6),
          ),
        ],
      ),
    ),
  );
}
