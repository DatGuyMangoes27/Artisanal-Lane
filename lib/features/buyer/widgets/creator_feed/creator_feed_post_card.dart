import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../removed_post_banner.dart';
import '../../../../app/theme.dart';
import '../../../../core/constants/feature_flags.dart';
import '../../../../core/pricing/price_format.dart';
import '../../../../core/ui/compact_count.dart';
import '../../../auth/providers/auth_providers.dart' show currentUserIdProvider;
import '../../providers/creator_safety_providers.dart';
import '../../providers/feed_video_playback.dart';
import '../../providers/post_social_providers.dart';
import '../content_report_sheet.dart';
import '../../../../models/shop_post.dart';
import 'post_poll_card.dart';
import 'post_social_bar.dart';
import 'creator_feed_media_viewer.dart';
import '../../../vendor/services/creator_post_media.dart';

class CreatorFeedPostCard extends ConsumerStatefulWidget {
  const CreatorFeedPostCard({
    super.key,
    required this.post,
    required this.isFollowing,
    required this.onOpenShop,
    required this.onFollowToggle,
  });

  final ShopPost post;
  final bool isFollowing;
  final VoidCallback onOpenShop;
  final Future<void> Function() onFollowToggle;

  @override
  ConsumerState<CreatorFeedPostCard> createState() =>
      _CreatorFeedPostCardState();
}

class _CreatorFeedPostCardState extends ConsumerState<CreatorFeedPostCard> {
  var _mediaIndex = 0;
  var _captionExpanded = false;

  @override
  void didUpdateWidget(covariant CreatorFeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        _mediaIndex >= widget.post.mediaUrls.length) {
      _mediaIndex = 0;
    }
  }

  void _openOptions() {
    final userId = ref.read(currentUserIdProvider);
    showPostOptionsSheet(
      context,
      ref,
      post: widget.post,
      onOpenShop: widget.onOpenShop,
      canReport: creatorSafetyEnabled && userId != null,
      onReport: () => showContentReportSheet(
        context,
        targetType: ContentReportTargetType.post,
        targetId: widget.post.id,
      ),
    );
  }

  void _openTaggedProducts() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, sheetRef, _) => sheetRef
              .watch(postProductsProvider(widget.post.id))
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('These products could not be loaded.'),
                ),
                data: (products) => ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Shop this post',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    ...products.map(
                      (p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: p.images.isEmpty
                              ? Container(
                                  width: 48,
                                  height: 48,
                                  color: AppTheme.bone,
                                )
                              : CachedNetworkImage(
                                  imageUrl: p.images.first,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        title: Text(p.title, maxLines: 2),
                        trailing: Text(formatBrowsePrice(p.price)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.push('/home/product/${p.id}');
                        },
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final media = post.mediaUrls;
    final creatorName = post.shopName?.trim().isNotEmpty == true
        ? post.shopName!
        : 'Artisan Lane maker';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 7, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.clay),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                InkWell(
                  onTap: widget.onOpenShop,
                  customBorder: const CircleBorder(),
                  child: _Avatar(imageUrl: post.shopLogoUrl, name: creatorName),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: widget.onOpenShop,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  creatorName,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (post.shopIsVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: AppTheme.terracotta,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            post.shopLocation?.trim().isNotEmpty == true
                                ? '${post.shopLocation!} · ${formatRelativeTime(post.publishedAt)}'
                                : formatRelativeTime(post.publishedAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (post.isScheduled) ...[
                            const SizedBox(height: 4),
                            _SchedulePill(scheduledFor: post.scheduledFor!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onFollowToggle();
                    },
                    // Follow is the call to action; Following stays quiet.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: widget.isFollowing
                          ? null
                          : AppTheme.terracotta,
                      foregroundColor: widget.isFollowing
                          ? AppTheme.textSecondary
                          : Colors.white,
                      side: BorderSide(
                        color: widget.isFollowing
                            ? AppTheme.sand
                            : AppTheme.terracotta,
                      ),
                    ),
                    child: Text(widget.isFollowing ? 'Following' : 'Follow'),
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    tooltip: 'Post options',
                    icon: const Icon(Icons.more_horiz),
                    onPressed: _openOptions,
                  ),
                ),
              ],
            ),
          ),
          if (post.isRemoved) RemovedPostBanner(post: post),
          AspectRatio(
            aspectRatio: 1.06,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PostMediaCarousel(
                  post: post,
                  index: _mediaIndex,
                  onIndexChanged: (i) => setState(() => _mediaIndex = i),
                ),
                if (post.productIds.isNotEmpty)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _RoundIconButton(
                      icon: Icons.shopping_bag_outlined,
                      tooltip: 'Shop this post',
                      onTap: _openTaggedProducts,
                    ),
                  ),
                if (media.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: _DotIndicator(
                      count: media.length,
                      index: _mediaIndex,
                    ),
                  ),
                if (post.format == PostFormat.tutorial && media.length > 1)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _StepBadge(
                      text: 'Step ${_mediaIndex + 1} of ${media.length}',
                    ),
                  ),
              ],
            ),
          ),
          if (post.format == PostFormat.tutorial &&
              _mediaIndex < post.stepCaptions.length &&
              post.stepCaptions[_mediaIndex].trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                post.stepCaptions[_mediaIndex],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (post.format == PostFormat.poll) PostPollCard(post: post),
          if (!post.isRemoved) PostSocialBar(post: post),
          if (post.caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: GestureDetector(
                onTap: () =>
                    setState(() => _captionExpanded = !_captionExpanded),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$creatorName  ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                      TextSpan(
                        text: post.caption,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      if (!_captionExpanded)
                        TextSpan(
                          text: '  more',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                        ),
                    ],
                  ),
                  maxLines: _captionExpanded ? null : 2,
                  overflow: _captionExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              post.caption.trim().isEmpty ? 12 : 0,
              16,
              14,
            ),
            child: InkWell(
              onTap: widget.onOpenShop,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 17,
                      color: AppTheme.terracotta,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Visit shop',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.terracotta,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: AppTheme.terracotta,
                    ),
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

/// Shown only to the maker themselves: the backend never returns a
/// scheduled post to anyone else until it goes live.
class _SchedulePill extends StatelessWidget {
  const _SchedulePill({required this.scheduledFor});
  final DateTime scheduledFor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.statusPending.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'Scheduled · ${DateFormat('d MMM, h:mm a').format(scheduledFor.toLocal())}',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    ),
  );
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.indigo.withValues(alpha: .78),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.indigo.withValues(alpha: .78),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    ),
  );
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      count,
      (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: i == index ? 16 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: i == index ? 0.95 : 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl, required this.name});
  final String? imageUrl;
  final String name;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 22,
    backgroundColor: AppTheme.bone,
    backgroundImage: imageUrl?.trim().isNotEmpty == true
        ? CachedNetworkImageProvider(imageUrl!)
        : null,
    child: imageUrl?.trim().isNotEmpty == true
        ? null
        : Text(
            name.characters.first.toUpperCase(),
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              color: AppTheme.terracotta,
            ),
          ),
  );
}

/// Swipeable media carousel with double-tap-to-like (never unlike, like
/// Instagram) and a heart-burst animation.
class _PostMediaCarousel extends ConsumerStatefulWidget {
  const _PostMediaCarousel({
    required this.post,
    required this.index,
    required this.onIndexChanged,
  });
  final ShopPost post;
  final int index;
  final ValueChanged<int> onIndexChanged;

  @override
  ConsumerState<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends ConsumerState<_PostMediaCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _page = PageController(initialPage: widget.index);
  late final AnimationController _heartController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void dispose() {
    _page.dispose();
    _heartController.dispose();
    super.dispose();
  }

  void _openViewer(int index) {
    final media = widget.post.mediaUrls;
    if (index < 0 || index >= media.length) return;
    final raw = media[index].trim();
    final isPrivate = isCreatorPostMediaMarker(raw);
    final isVideo = isPrivate || isCreatorFeedVideoUrl(raw);
    if (!isPrivate && !isCreatorFeedHttpsUrl(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVideo
                ? 'This video needs a secure link.'
                : 'This photo needs a secure link.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            CreatorFeedMediaViewer(mediaUrls: media, initialIndex: index),
      ),
    );
  }

  Future<void> _doubleTapLike() async {
    final engagement = ref.read(postEngagementProvider(widget.post.id)).value;
    if (engagement?.liked == true) return;
    _heartController.forward(from: 0);
    await togglePostLike(
      ref,
      context,
      post: widget.post,
      currentlyLiked: engagement?.liked ?? false,
      likeOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.post.mediaUrls;
    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          media.isEmpty
              ? const _EmptyMedia()
              : PageView.builder(
                  controller: _page,
                  itemCount: media.length,
                  onPageChanged: widget.onIndexChanged,
                  itemBuilder: (context, i) => _PostMedia(
                    postId: widget.post.id,
                    url: media[i],
                    onTap: () => _openViewer(i),
                  ),
                ),
          IgnorePointer(
            child: Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _heartController,
                  curve: const Interval(0, .55, curve: Curves.elasticOut),
                ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _heartController,
                    curve: const Interval(.55, 1, curve: Curves.easeOut),
                  ).drive(Tween(begin: 1, end: 0)),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 96,
                    shadows: [Shadow(blurRadius: 18, color: Colors.black38)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedia extends StatelessWidget {
  const _EmptyMedia();
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.bone,
    alignment: Alignment.center,
    child: const Icon(Icons.photo_outlined, size: 42, color: AppTheme.textHint),
  );
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({
    required this.postId,
    required this.url,
    required this.onTap,
  });
  final String postId;
  final String? url;
  final VoidCallback onTap;
  bool get _isPrivateVideo => isCreatorPostMediaMarker(url ?? '');
  bool get _isVideo => _isPrivateVideo || isCreatorFeedVideoUrl(url);

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) return const _EmptyMedia();
    if (_isVideo) {
      // Autoplay only kicks in for a video we could actually play (a
      // private marker, or an https url); anything else keeps the old
      // tap-to-open behaviour so the viewer's own safety check can explain
      // the block, instead of silently doing nothing when tapped.
      final playable = _isPrivateVideo || isCreatorFeedHttpsUrl(url);
      if (!creatorVideoPostsEnabled || !playable) {
        return _VideoThumb(
          onTap: onTap,
          keyName: _isPrivateVideo
              ? 'open-creator-feed-private-video'
              : 'open-creator-feed-video',
        );
      }
      return _InlineFeedVideo(
        postId: postId,
        raw: url!,
        onOpenFullScreen: onTap,
      );
    }
    return InkWell(
      key: const Key('open-creator-feed-photo'),
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, __) => Container(color: AppTheme.bone),
        errorWidget: (_, __, ___) => Container(
          color: AppTheme.bone,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppTheme.textHint,
          ),
        ),
      ),
    );
  }
}

/// Static "watch video" placeholder: used when videos aren't autoplay-able
/// (feature flag off), as the loading state before playback starts, and as
/// the tap-to-retry state when a video could not be loaded.
class _VideoThumb extends StatelessWidget {
  const _VideoThumb({
    required this.onTap,
    this.keyName,
    this.loading = false,
    this.failed = false,
  });
  final VoidCallback onTap;
  final String? keyName;
  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) => InkWell(
    key: keyName == null ? null : Key(keyName!),
    onTap: onTap,
    child: Container(
      color: AppTheme.indigo,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(
                  failed
                      ? Icons.refresh_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 54,
                  color: Colors.white,
                ),
          const SizedBox(height: 8),
          Text(
            failed ? "Video didn't load. Tap to try again" : 'Watch video',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

/// In-feed video: muted autoplay while ≥60% visible (driven by
/// [activeFeedVideoPostIdProvider], updated by the feed screen from scroll
/// position), tap to mute/unmute, tap-and-hold or the expand button to open
/// the full-screen viewer. Private videos are signed lazily, only once this
/// post becomes the active one, and the controller is disposed as soon as
/// it stops being active.
class _InlineFeedVideo extends ConsumerStatefulWidget {
  const _InlineFeedVideo({
    required this.postId,
    required this.raw,
    required this.onOpenFullScreen,
  });
  final String postId;
  final String raw;
  final VoidCallback onOpenFullScreen;

  @override
  ConsumerState<_InlineFeedVideo> createState() => _InlineFeedVideoState();
}

class _InlineFeedVideoState extends ConsumerState<_InlineFeedVideo> {
  VideoPlayerController? _controller;
  Object? _error;
  var _loading = false;

  bool get _isPrivate => isCreatorPostMediaMarker(widget.raw);

  @override
  void initState() {
    super.initState();
    // A card rebuilt while its post is already the active one (e.g. scrolled
    // back into view) gets no change notification, so start it here instead
    // of leaving it on a spinner.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(activeFeedVideoPostIdProvider) == widget.postId) {
        _activate();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineFeedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raw != widget.raw) {
      _disposeController();
      _error = null;
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerChanged);
    controller?.pause();
    controller?.dispose();
  }

  /// Playback can still fail after a successful initialize (dropped
  /// connection, decoder error). Surface it as the retry state instead of a
  /// frozen frame.
  void _onControllerChanged() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.hasError) return;
    _disposeController();
    setState(() => _error = 'Playback failed');
  }

  /// Private videos are signed for a few minutes only, so a fresh URL is
  /// requested on every activation rather than reusing one that may have
  /// expired while the post was scrolled away.
  Future<String> _playableUrl() async {
    final url = _isPrivate
        ? await CreatorPostMediaRepository(
            Supabase.instance.client,
          ).signedUrlFor(widget.raw)
        : widget.raw;
    if (url == null || !isCreatorFeedHttpsUrl(url)) {
      throw StateError('Video unavailable');
    }
    return url;
  }

  Future<void> _activate() async {
    if (_controller != null || _loading || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    VideoPlayerController? controller;
    try {
      final url = await _playableUrl();
      if (!mounted) return;
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted ||
          ref.read(activeFeedVideoPostIdProvider) != widget.postId) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      final unmuted = ref
          .read(feedVideoUnmutedPostIdsProvider)
          .contains(widget.postId);
      await controller.setVolume(unmuted ? 1 : 0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onControllerChanged);
      setState(() => _controller = controller);
    } catch (error) {
      // A controller that failed to initialize is never handed to the
      // widget, so release its native player here.
      if (controller != null && controller != _controller) {
        await controller.dispose().catchError((_) {});
      }
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _deactivate() {
    _disposeController();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(activeFeedVideoPostIdProvider) == widget.postId;
    ref.listen<String?>(activeFeedVideoPostIdProvider, (previous, next) {
      final wasActive = previous == widget.postId;
      final nowActive = next == widget.postId;
      if (nowActive && !wasActive) _activate();
      if (!nowActive && wasActive) _deactivate();
    });
    final unmuted = ref
        .watch(feedVideoUnmutedPostIdsProvider)
        .contains(widget.postId);
    _controller?.setVolume(unmuted ? 1 : 0);

    return GestureDetector(
      key: Key(
        _isPrivate
            ? 'inline-creator-feed-private-video-${widget.postId}'
            : 'inline-creator-feed-video-${widget.postId}',
      ),
      behavior: HitTestBehavior.opaque,
      onTap: () => ref
          .read(feedVideoUnmutedPostIdsProvider.notifier)
          .toggle(widget.postId),
      onLongPress: widget.onOpenFullScreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (_error != null)
            _VideoThumb(
              keyName: 'retry-inline-creator-feed-video',
              onTap: _activate,
              failed: true,
            )
          else
            _VideoThumb(
              onTap: widget.onOpenFullScreen,
              loading: _loading || isActive,
            ),
          if (_controller != null)
            Positioned(
              right: 14,
              bottom: 14,
              child: _RoundIconButton(
                icon: unmuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                tooltip: unmuted ? 'Mute' : 'Unmute',
                onTap: () => ref
                    .read(feedVideoUnmutedPostIdsProvider.notifier)
                    .toggle(widget.postId),
              ),
            ),
          Positioned(
            top: 14,
            right: 14,
            child: _RoundIconButton(
              key: const Key('open-creator-feed-video-fullscreen'),
              icon: Icons.fullscreen_rounded,
              tooltip: 'Full screen',
              onTap: widget.onOpenFullScreen,
            ),
          ),
        ],
      ),
    );
  }
}
