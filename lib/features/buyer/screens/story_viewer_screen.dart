import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/ui/compact_count.dart' show formatRelativeTime;
import '../../../core/ui/friendly_error.dart';
import '../../../models/shop_story.dart';
import '../../../widgets/sign_in_prompt_sheet.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/creator_safety_providers.dart';
import '../providers/story_providers.dart';
import '../utils/shop_profile_actions.dart';
import '../widgets/content_report_sheet.dart';
import '../widgets/stories/story_reaction_bar.dart';
import '../widgets/stories/story_reactions_pill.dart';
import '../widgets/story_media.dart';

class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialStoryIndex = 0,
    this.ownShopId,
  });

  /// Every maker's story group, in the same order shown by the rail.
  final List<List<ShopStory>> groups;
  final int initialGroupIndex;
  final int initialStoryIndex;
  final String? ownShopId;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  late final AnimationController _progress;
  late final AnimationController _dismiss;
  late int _groupIndex;
  late int _index;
  late Future<Uint8List> _media;
  final Map<String, Future<Uint8List>> _mediaCache = {};
  Timer? _expiry;
  bool _paused = false, _ready = false, _deleting = false;
  bool _mediaFailed = false;
  bool _pendingGroupAtEnd = false;
  bool _wasPlayingBeforeDismiss = false;
  String? _autoSkipScheduledFor;

  static const double _dismissDistance = 260;

  List<ShopStory> get _group => widget.groups[_groupIndex];
  ShopStory get _story => _group[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _groupIndex = widget.initialGroupIndex;
    _index = widget.initialStoryIndex;
    _pageController = PageController(initialPage: _groupIndex);
    _progress = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _move(1);
      });
    _dismiss = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    ref.listenManual(currentUserIdProvider, (old, next) {
      if (old != next && mounted) _close();
    });
    _load();
  }

  void _load() {
    _ready = false;
    _mediaFailed = false;
    _autoSkipScheduledFor = null;
    _progress.reset();
    _media = _mediaFuture(_story);
    _expiry?.cancel();
    _expiry = Timer(_story.expiresAt.difference(DateTime.now()), () {
      if (mounted) _close();
    });
    _prefetchNeighbors();
  }

  /// Cached so switching to an already-downloaded story shows no spinner.
  /// A silent listener is attached immediately so a prefetch failure for a
  /// story that isn't on screen yet never surfaces as an unhandled error.
  Future<Uint8List> _mediaFuture(ShopStory story) {
    return _mediaCache.putIfAbsent(story.id, () {
      final future = ref.read(storyRepositoryProvider).media(story);
      future.then((_) {}, onError: (_) {});
      return future;
    });
  }

  void _prefetchNeighbors() {
    ShopStory? next;
    if (_index + 1 < _group.length) {
      next = _group[_index + 1];
    } else if (_groupIndex + 1 < widget.groups.length) {
      final nextGroup = widget.groups[_groupIndex + 1];
      if (nextGroup.isNotEmpty) next = nextGroup.first;
    }
    if (next != null) _mediaFuture(next);
    final keep = {_story.id, if (next != null) next.id};
    _mediaCache.removeWhere((id, _) => !keep.contains(id));
  }

  int _firstUnseenOrZero(int groupIndex) {
    final seen = {
      ...ref.read(seenStoriesProvider).value ?? <String>{},
      ...ref.read(locallySeenStoriesProvider),
    };
    final idx = widget.groups[groupIndex].indexWhere(
      (s) => !seen.contains(s.id),
    );
    return idx < 0 ? 0 : idx;
  }

  void _move(int offset) {
    var next = _index + offset;
    while (next >= 0 &&
        next < _group.length &&
        !_group[next].isLiveAt(DateTime.now())) {
      next += offset;
    }
    if (next < 0) {
      if (_groupIndex > 0) _goToGroup(_groupIndex - 1, atEnd: true);
      return;
    }
    if (next >= _group.length) {
      if (_groupIndex < widget.groups.length - 1) {
        _goToGroup(_groupIndex + 1, atEnd: false);
      } else {
        _close();
      }
      return;
    }
    setState(() {
      _index = next;
      _load();
    });
  }

  void _goToGroup(int groupIndex, {required bool atEnd}) {
    _pendingGroupAtEnd = atEnd;
    _pageController.animateToPage(
      groupIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int page) {
    if (page == _groupIndex) return;
    final atEnd = _pendingGroupAtEnd;
    _pendingGroupAtEnd = false;
    final group = widget.groups[page];
    final startIndex = atEnd
        ? (group.isEmpty ? 0 : group.length - 1)
        : _firstUnseenOrZero(page);
    setState(() {
      _groupIndex = page;
      _index = startIndex;
      _load();
    });
  }

  void _close() {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    // Dismiss our confirmation dialog too, without leaving expired media open.
    Navigator.of(context).popUntil((candidate) => candidate == route);
    Navigator.of(context).pop();
  }

  void _pause(bool value) {
    if (_paused == value) return;
    setState(() => _paused = value);
    if (value) {
      _progress.stop();
    } else if (_ready) {
      _progress.forward();
    }
  }

  void _onReady(Duration duration) {
    if (!mounted || !_story.isLiveAt(DateTime.now())) return;
    _ready = true;
    _progress.duration = duration > const Duration(seconds: 60)
        ? const Duration(seconds: 60)
        : duration;
    if (!_paused) _progress.forward();
    // Optimistic: the rail's seen ring updates immediately, without waiting
    // for a refetch of shop_story_views.
    ref.read(locallySeenStoriesProvider.notifier).add(_story.id);
    ref
        .read(storyRepositoryProvider)
        .markSeen(_story.id)
        .then((_) {
          if (mounted) ref.invalidate(seenStoriesProvider);
        })
        .catchError((Object _) {
          /* Viewing still works if receipt delivery fails. */
        });
  }

  void _onMediaFailed(ShopStory story) {
    if (_autoSkipScheduledFor == story.id) return;
    _autoSkipScheduledFor = story.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _story.id != story.id) return;
      setState(() => _mediaFailed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              null,
              fallback: "Couldn't load ${story.shopName}'s story. Skipping.",
            ),
          ),
          backgroundColor: Colors.black87,
        ),
      );
      _move(1);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) _pause(true);
  }

  Future<void> _delete() async {
    _pause(true);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this story?'),
        content: const Text('It will disappear from your story immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep story'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (yes != true) {
      _pause(false);
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(storyRepositoryProvider).delete(_story);
      if (!mounted) return;
      ref.invalidate(storiesProvider);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                error,
                fallback: 'Could not delete. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _report() async {
    _pause(true);
    await showContentReportSheet(
      context,
      targetType: ContentReportTargetType.story,
      targetId: _story.id,
    );
    if (mounted) _pause(false);
  }

  Future<void> _openShop(ShopStory story) async {
    _pause(true);
    await context.push('/home/shop/${story.shopId}');
    if (mounted) _pause(false);
  }

  Future<void> _sendMessage(ShopStory story) async {
    _pause(true);
    final userId = ref.read(currentUserIdProvider);
    try {
      await handleShopMessageTap(
        userId: userId,
        promptSignIn: () => showSignInPromptSheet(
          context,
          title: 'Sign in to message artisans',
          message:
              'Create an account or sign in to start a conversation with ${story.shopName}.',
        ),
        createOrGetThreadId: (buyerId) async {
          final thread = await ref
              .read(supabaseServiceProvider)
              .getOrCreateThread(shopId: story.shopId, buyerId: buyerId);
          return thread.id;
        },
        openChat: (route) async {
          if (!mounted) return;
          await context.push(route);
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                error,
                fallback: 'Could not open chat. Please try again.',
              ),
            ),
          ),
        );
      }
    }
    if (mounted) _pause(false);
  }

  void _onDismissStart(DragStartDetails details) {
    _wasPlayingBeforeDismiss = !_paused;
    _pause(true);
  }

  void _onDismissUpdate(DragUpdateDetails details) {
    if (details.delta.dy == 0) return;
    final current = _dismiss.value * _dismissDistance;
    final next = (current + details.delta.dy).clamp(0.0, _dismissDistance);
    _dismiss.value = next / _dismissDistance;
  }

  void _onDismissEnd(DragEndDetails details) {
    final shouldDismiss =
        _dismiss.value > 0.35 || details.velocity.pixelsPerSecond.dy > 700;
    if (shouldDismiss) {
      _dismiss
          .animateTo(1, duration: const Duration(milliseconds: 160))
          .whenComplete(() {
            if (mounted) Navigator.pop(context);
          });
    } else {
      _dismiss
          .animateTo(
            0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && _wasPlayingBeforeDismiss) _pause(false);
          });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiry?.cancel();
    _progress.dispose();
    _dismiss.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _progressBars(List<ShopStory> group, int currentIndex, bool active) {
    if (!active) {
      return Row(
        children: List.generate(
          group.length,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: LinearProgressIndicator(
                value: i < currentIndex ? 1 : 0,
                minHeight: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, _) => Row(
        children: List.generate(
          group.length,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: LinearProgressIndicator(
                value: i < currentIndex
                    ? 1
                    : i == currentIndex
                    ? _progress.value
                    : 0,
                minHeight: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ShopStory story) => Row(
    children: [
      const SizedBox(width: 12),
      Expanded(
        child: Semantics(
          button: true,
          label: "Open ${story.shopName}'s shop",
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openShop(story),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    backgroundImage: story.logoUrl != null
                        ? CachedNetworkImageProvider(story.logoUrl!)
                        : null,
                    child: story.logoUrl == null
                        ? Text(
                            story.shopName.isEmpty
                                ? '?'
                                : story.shopName.characters.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          story.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          formatRelativeTime(story.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
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
      ),
      if (story.shopId == widget.ownShopId)
        IconButton(
          tooltip: 'Delete story',
          onPressed: _deleting ? null : _delete,
          icon: const Icon(Icons.delete_outline, color: Colors.white),
        ),
      if (creatorSafetyEnabled &&
          ref.watch(currentUserIdProvider) != null &&
          story.shopId != widget.ownShopId)
        IconButton(
          tooltip: 'Report story',
          onPressed: _report,
          icon: const Icon(Icons.flag_outlined, color: Colors.white),
        ),
      IconButton(
        tooltip: 'Close story',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close, color: Colors.white),
      ),
      const SizedBox(width: 4),
    ],
  );

  Widget _bottomBar(ShopStory story) {
    if (story.shopId == widget.ownShopId) {
      if (_mediaFailed) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: StoryReactionsPill(story: story, onSheetOpenChanged: _pause),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              onPressed: () => _openShop(story),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: const Text('Visit shop'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              onPressed: () => _sendMessage(story),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send message'),
            ),
          ),
          if (!_mediaFailed) ...[
            const SizedBox(width: 10),
            StoryReactionBar(story: story, onExpandChanged: _pause),
          ],
        ],
      ),
    );
  }

  Widget _mediaArea(ShopStory story) => GestureDetector(
    key: const ValueKey('story-media-gesture'),
    onLongPressStart: (_) {
      HapticFeedback.selectionClick();
      _pause(true);
    },
    onLongPressEnd: (_) => _pause(false),
    child: Semantics(
      label: _paused
          ? '${story.shopName}’s story, paused'
          : '${story.shopName}’s story, playing',
      onLongPress: () => _pause(!_paused),
      child: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<Uint8List>(
              key: ValueKey(story.id),
              future: _media,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  _onMediaFailed(story);
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white38),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StoryMedia(
                  key: ValueKey(story.id),
                  bytes: snapshot.data!,
                  video: story.isVideo,
                  paused: _paused,
                  onReady: _onReady,
                );
              },
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Previous story',
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _move(-1),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Semantics(
                    button: true,
                    label: 'Next story',
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _move(1),
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

  Widget _groupPage(int groupIndex) {
    final group = widget.groups[groupIndex];
    final active = groupIndex == _groupIndex;
    final index = active ? _index : 0;
    final story = group.isEmpty
        ? null
        : group[index.clamp(0, group.length - 1)];
    if (story == null) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _progressBars(group, index, active),
        ),
        _header(story),
        Expanded(
          child: active
              ? _mediaArea(story)
              : ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: story.logoUrl != null
                        ? Opacity(
                            opacity: 0.35,
                            child: CachedNetworkImage(
                              imageUrl: story.logoUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
        ),
        if (active && story.caption.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                story.caption,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (active) _bottomBar(story) else const SizedBox(height: 44),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor: Colors.black,
    ),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragStart: _onDismissStart,
        onVerticalDragUpdate: _onDismissUpdate,
        onVerticalDragEnd: _onDismissEnd,
        child: AnimatedBuilder(
          animation: _dismiss,
          builder: (context, child) {
            final t = _dismiss.value;
            return Opacity(
              opacity: 1 - t * 0.6,
              child: Transform.scale(
                scale: 1 - t * 0.15,
                child: Transform.translate(
                  offset: Offset(0, t * _dismissDistance),
                  child: child,
                ),
              ),
            );
          },
          child: SafeArea(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.groups.length,
              itemBuilder: (context, i) => _groupPage(i),
            ),
          ),
        ),
      ),
    ),
  );
}
